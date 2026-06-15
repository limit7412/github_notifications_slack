require "json"
require "log"
require "http/client"

module Serverless
  module Lambda
    extend self

    Log = ::Log.for("lambda")

    def handler(name : String, &)
      return if name != ENV["_HANDLER"]

      ENV["SSL_CERT_FILE"] = "/etc/pki/tls/cert.pem"

      loop do
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

    # CloudWatch では改行ごとにログエントリが分割されるため、改行を除去して
    # 1 エントリにまとめつつ、長い本文は適度なチャンクに分割して出力する。
    # 中間の Array(Char) を作らずに済むよう文字列スライスで分割する。
    def print_log(log : String)
      cleaned = log.gsub(/(\r\n|\r|\n|\f)/, "")
      offset = 0
      while offset < cleaned.size
        Log.info { cleaned[offset, 50000] }
        offset += 50000
      end
    end
  end
end
