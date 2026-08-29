require "uri"
require "http/client"

module Webhook
  # webhook URL へ JSON を POST する。
  #
  # Slack と Discord のアダプタは投稿の組み立て方こそ違うが、「webhook URL に
  # JSON を POST し、一時的な失敗は再送する」点は同じで、再送の判断と待機が
  # 二重に書かれていた（issue #123）。片方だけ直すと挙動がずれるため、送信そのものは
  # ここにまとめ、アダプタは投稿の組み立てに専念する。
  class Client
    MAX_SEND_ATTEMPTS = 3         # 送信リトライ回数の上限
    MAX_RETRY_WAIT    = 5.seconds # Retry-After の待機上限

    # service はエラーメッセージに出す送信先の名前。
    def initialize(@service : String, url : String)
      @uri = URI.parse url
      @client = HTTP::Client.new @uri
    end

    # 送信できたら戻り、恒久的に失敗したら例外にする。
    #
    # 呼び出し側は投稿の成功を前提に通知を既読化する。応答を見ずに成功扱いにすると、
    # 投稿されていない通知まで既読化され、どこにも表示されないまま消える（issue #120）。
    # よって失敗は握りつぶさず例外にし、既読化を止めて次回実行に委ねる。
    def post(body : String)
      attempt = 0
      loop do
        attempt += 1
        res = post_json body
        return if res.success?

        # 通知は複数の投稿に分割されうるため、1 実行で webhook を連続して叩く。
        # レート制限（429）や一時的な 5xx でその実行を丸ごと落とすと通知が遅れるので、
        # Retry-After に従って再送する。
        retryable = res.status.code == 429 || res.status.server_error?
        if retryable && attempt < MAX_SEND_ATTEMPTS
          sleep retry_after(res)
          next
        end

        raise "#{@service} webhook returned #{res.status_code}: #{res.body}"
      end
    end

    # 送信の実体。ここだけを差し替えれば、HTTP を張らずに再送の判断を試せる。
    private def post_json(body : String) : HTTP::Client::Response
      headers = HTTP::Headers{"Content-Type" => "application/json"}
      @client.post(@uri.request_target, headers: headers, body: body)
    end

    # 待機時間は Retry-After に従う。ヘッダが無ければ 1 秒、長すぎる指定は
    # Lambda の実行時間を食い潰さないよう上限で丸める。
    private def retry_after(res : HTTP::Client::Response) : Time::Span
      seconds = res.headers["Retry-After"]?.try(&.to_f?) || 1.0
      seconds.seconds.clamp(Time::Span.zero, MAX_RETRY_WAIT)
    end
  end
end
