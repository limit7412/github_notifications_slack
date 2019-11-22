require "json"
require "http/client"

module Lambda
  extend self

  def handler(name : String)
    return if name != ENV["_HANDLER"]

    ENV["SSL_CERT_FILE"] = "/etc/pki/tls/cert.pem"

    while true
      response = HTTP::Client.get "http://#{ENV["AWS_LAMBDA_RUNTIME_API"]}/2018-06-01/runtime/invocation/next"
      event = JSON.parse(response.body)
      request_id = response.headers["Lambda-Runtime-Aws-Request-Id"]

      begin
        body = yield event
        header = nil
        url = "http://#{ENV["AWS_LAMBDA_RUNTIME_API"]}/2018-06-01/runtime/invocation/#{request_id}/response"
      rescue err
        body = {
          msg: "Internal Lambda Error",
          err: err.message,
        }
        header = HTTP::Headers{"Lambda-Runtime-Function-Error-Type" => "Unhandled"}
        url = "http://#{ENV["AWS_LAMBDA_RUNTIME_API"]}/2018-06-01/runtime/invocation/#{request_id}/error"
      end

      HTTP::Client.post url, headers: header, body: body.to_json
    end
  end
end
