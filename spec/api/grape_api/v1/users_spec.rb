# frozen_string_literal: true

require "rails_helper"

describe API::V1::Users do
  let(:user_data) do
    {
      username:     "solomon",
      email:        "solomon@example.org",
      password:     "password",
      display_name: "Solomon Gandy"
    }
  end

  before do
    admin = create :admin
    token = create :application_token, user: admin
    @header = build_token_header(token)

    APP_CONFIG["first_user_admin"] = { "enabled" => true }
  end

  context "GET /api/v1/users" do
    it "returns list of users" do
      create :user
      get "/api/v1/users", nil, @header
      expect(response).to have_http_status(:success)
      expect(User.count).to eq 2
      expect(JSON.parse(response.body).size).to eq 2
    end

    it "authentication fails" do
      get "/api/v1/users"
      expect(response).to have_http_status(:unauthorized)
    end

    it "authorization fails" do
      token = create :application_token
      header = { "PORTUS-AUTH" => "#{token.user.username}:#{token.application}" }
      get "/api/v1/users", nil, header
      expect(response).to have_http_status(:forbidden)
    end
  end

  context "GET /api/v1/users/:id" do
    let(:user) { create(:user) }

    it "returns user by id" do
      get "/api/v1/users/#{user["id"]}", nil, @header
      expect(response).to have_http_status(:success)

      data = JSON.parse(response.body)
      expect(data["username"]).to eq user["username"]
    end

    it "authorization fails" do
      token = create :application_token
      header = { "PORTUS-AUTH" => "#{token.user.username}:#{token.application}" }
      get "/api/v1/users/#{token.user.id}", nil, header
      expect(response).to have_http_status(:forbidden)
    end

    it "returns user by email" do
      get "/api/v1/users/#{user["email"]}", nil, @header
      expect(response).to have_http_status(:success)

      data = JSON.parse(response.body)
      expect(data["id"]).to eq user["id"]
    end

    it "returns status 404" do
      user_id = User.maximum(:id) + 1
      get "/api/v1/users/#{user_id}", nil, @header
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/users" do
    context "with valid params" do
      it "creates new user" do
        post "/api/v1/users", { user: user_data }, @header
        expect(response).to have_http_status(:created)
        expect(User.find_by(email: user_data[:email])).not_to be_nil
      end
    end

    context "with invalid params" do
      it "returns errors" do
        post "/api/v1/users", { user: { username: "", email: "", password: "" } },
             @header
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["message"]).not_to be_nil
      end

      it "returns user error" do
        post "/api/v1/users", {}, @header
        expect(response).to have_http_status(:bad_request)
      end
    end

    it "with invalid JSON returns error" do
      headers = @header.merge(
        "Content-Type": "application/json",
        "Accept":       "application/json"
      )
      post "/api/v1/users", '{"user":{"username"', headers
      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)["message"]).not_to be nil
    end
  end

  describe "PUT /api/v1/users/:id" do
    context "with valid params" do
      it "updates user" do
        user = create :user
        put "/api/v1/users/#{user.id}", { user: user_data }, @header
        expect(response).to have_http_status(:success)
        expect(User.find_by(email: user_data[:email])).not_to be_nil
      end

      it "updates user but not display_name" do
        user = create :user, display_name: "John Smith"
        put "/api/v1/users/#{user.id}", { user: user_data.except(:display_name) },
            @header
        expect(response).to have_http_status(:success)
        expect(User.find(user.id).display_name).to eq user.display_name
      end
    end

    context "with invalid params" do
      it "returns duplicate username errors" do
        user = create :user
        user2 = create :user
        put "/api/v1/users/#{user.id}", { user: { username: user2.username } }, @header
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["message"]).not_to be_nil
      end

      it "returns status not found" do
        create :user
        user_id = User.maximum(:id) + 1
        put "/api/v1/users/#{user_id}", { user: user_data }, @header
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context "DELETE /api/v1/users/:id" do
    it "deletes user" do
      user = create :user
      delete "/api/v1/users/#{user.id}", nil, @header
      expect(response).to have_http_status(:no_content)
      expect { User.find(user.id) }.to raise_exception(ActiveRecord::RecordNotFound)
    end

    it "returns status 404" do
      user_id = User.maximum(:id) + 1
      delete "/api/v1/users/#{user_id}", nil, @header
      expect(response).to have_http_status(:not_found)
    end
  end

  context "GET /api/v1/users/:id/application_tokens" do
    it "returns list of user's tokens" do
      user = create :user
      create_list :application_token, 5, user: user
      get "/api/v1/users/#{user.id}/application_tokens", nil, @header
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body).size).to eq 5
    end

    it "returns status 404" do
      user_id = User.maximum(:id) + 1
      get "/api/v1/users/#{user_id}/application_tokens", nil, @header
      expect(response).to have_http_status(:not_found)
    end
  end

  context "POST /api/v1/users/:id/application_tokens" do
    it "creates user's token" do
      user = create :user
      post "/api/v1/users/#{user.id}/application_tokens", \
           { application: "test" }, @header
      expect(response).to have_http_status(:success)
      expect(ApplicationToken.count).to eq 2
      expect(JSON.parse(response.body)).not_to be_nil
    end

    it "returns errors on existing application" do
      token = create :application_token

      post "/api/v1/users/#{token.user_id}/application_tokens", \
           { application: token.application }, @header
      expect(response).to have_http_status(:unprocessable_entity)

      resp = JSON.parse(response.body)
      expect(resp["message"]["application"].first).to eq("has already been taken")
    end

    it "returns server error" do
      token = create :application_token
      post "/api/v1/users/#{token.user_id}/application_tokens",
           { application: nil }, @header
      expect(response).to have_http_status(:internal_server_error)
    end

    it "returns a 400 for malformed JSON" do
      user = create :user

      @header = @header.merge(
        "CONTENT_TYPE" => "application/json",
        "ACCEPT"       => "application/json"
      )
      post "/api/v1/users/#{user.id}/application_tokens", "{", @header
      expect(response).to have_http_status(:bad_request)

      resp = JSON.parse(response.body)
      expect(resp["message"]).to match(/There was a problem in the JSON you submitted/)
    end
  end

  context "DELETE /api/v1/users/application_tokens/:id" do
    it "deletes application_token" do
      token = create :application_token
      delete "/api/v1/users/application_tokens/#{token.id}", nil, @header
      expect(response).to have_http_status(:no_content)
      expect { ApplicationToken.find(token.id) }.to \
        raise_exception(ActiveRecord::RecordNotFound)
    end

    it "returns status 404" do
      token_id = ApplicationToken.maximum(:id) + 1
      delete "/api/v1/users/application_tokens/#{token_id}", nil, @header
      expect(response).to have_http_status(:not_found)
    end
  end

  it "DELETE /api/v1/users/:id/application_tokens/:id returns status 404" do
    user = create :user
    token = create :application_token, user: user
    delete "/api/v1/users/#{user.id}/application_tokens/#{token.id}", nil, @header
    expect(response).to have_http_status(:not_found)
  end

  context "POST /api/v1/users/bootstrap" do
    it "returns 400 if there is already a user available" do
      create :user
      post "/api/v1/users/bootstrap", { user: user_data }, @header
      expect(response).to have_http_status(:bad_request)

      msg = JSON.parse(response.body)
      expect(msg["message"]).to eq(
        "you can only use this when there are no users on the system"
      )
    end

    it "returns the application token if everything went fine" do
      # Destroy all users and create the portus one. This will check that it
      # ignores the portus user when creating this new admin.
      User.destroy_all
      create(:user, username: "portus")

      expect do
        post "/api/v1/users/bootstrap", { user: user_data }, nil
      end.to change { ApplicationToken.count }.from(0).to(1)

      expect(response).to have_http_status(:created)

      msg = JSON.parse(response.body)
      expect(msg["plain_token"]).not_to be_empty
    end

    it "makes sure that the created user is an admin" do
      User.destroy_all

      post "/api/v1/users/bootstrap", { user: user_data }, nil
      expect(response).to have_http_status(:created)

      expect(User.first.admin?).to be_truthy
    end

    it "returns a 405 if first_user_admin was disabled" do
      APP_CONFIG["first_user_admin"] = { "enabled" => false }
      post "/api/v1/users/bootstrap", { user: user_data }, @header
      expect(response).to have_http_status(:method_not_allowed)
    end

    it "returns a 422 when the supplied parameters have a bad format" do
      User.destroy_all
      data = user_data
      data[:email] = "bad"

      post "/api/v1/users/bootstrap", { user: data }, nil
      expect(response).to have_http_status(:unprocessable_entity)

      msg = JSON.parse(response.body)
      expect(msg["message"]["email"].first).to eq "is invalid"
    end
  end
end
