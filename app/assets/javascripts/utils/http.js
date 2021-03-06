import Alert from '~/shared/components/alert';

export function handleHttpResponseError(response) {
  const errors = response.data.message;
  let messages = [];

  if (typeof errors === 'string') {
    messages = [errors];
  } else if (Array.isArray(errors)) {
    messages = errors;
  } else if (Object.prototype.toString.call(errors) === '[object Object]') {
    Object.keys(errors).forEach((k) => {
      const keyCapitalized = k.charAt(0).toUppercase() + k.substr(1);
      messages = messages.concat(errors[k].map(m => `${keyCapitalized} ${m}`));
    });
  }

  Alert.$show(messages.join('<br />'));
}

export default {
  handleHttpResponseError,
};
