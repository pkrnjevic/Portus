# frozen_string_literal: true

class NamespacesController < ApplicationController
  before_action :set_namespace, only: %i[change_visibility show]

  after_action :verify_authorized, except: %i[index typeahead]
  after_action :verify_policy_scoped, only: :index

  # GET /namespaces
  def index
    respond_to do |format|
      format.html { skip_policy_scope }
    end
  end

  # GET /namespaces/1
  # GET /namespaces/1.json
  def show
    raise ActiveRecord::RecordNotFound if @namespace.portus?

    authorize @namespace
    @repositories = @namespace.repositories.page(params[:page])
    @namespace_serialized = API::Entities::Namespaces.represent(
      @namespace,
      current_user: current_user,
      type:         :internal
    ).to_json

    respond_with(@namespace)
  end

  # GET /namespace/typeahead/%QUERY
  def typeahead
    valid_teams_ids = if current_user.admin?
                        Team.all_non_special.pluck(:id)
                      else
                        TeamUser.get_valid_team_ids(current_user.id)
                      end

    query = "#{params[:query]}%"
    matches = Team.search_from_query(valid_teams_ids, query).pluck(:name)
    matches = matches.map { |team| { name: ActionController::Base.helpers.sanitize(team) } }
    respond_to do |format|
      format.json { render json: matches.to_json }
    end
  end

  # PATCH/PUT /namespace/1/change_visibility.json
  def change_visibility
    authorize @namespace

    # Update the visibility if needed
    return if visibility_param == @namespace.visibility

    return unless @namespace.update(visibility: visibility_param)

    @namespace.create_activity :change_visibility,
                               owner:      current_user,
                               parameters: { visibility: @namespace.visibility }

    respond_to do |format|
      format.js { render :change_visibility }
      format.json { render json: @namespace }
    end
  end

  private

  # Normalizes visibility parameter
  def visibility_param
    value = params[:visibility]
    value = "visibility_#{value}" unless value.start_with?("visibility_")
    value
  end

  def set_namespace
    @namespace = Namespace.find(params[:id])
  end
end
