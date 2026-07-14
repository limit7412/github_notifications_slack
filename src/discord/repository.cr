require "json"
require "uri"
require "http/client"
require "./models"
require "../notify/models"
require "../notify/repository"
require "../runtime/lambda"

module Discord
  class PostRepository < Notify::PostRepository
    MAX_SEND_ATTEMPTS = 3         # 送信リトライ回数の上限
    MAX_RETRY_WAIT    = 5.seconds # Retry-After の待機上限

    def initialize(url : String)
      @uri = URI.parse url
      @client = HTTP::Client.new @uri
    end

    def send_messages(messages : Array(Notify::Message), & : Int32 ->)
      # 通知は複数の webhook 投稿（チャンク）に分割されうる。1 投稿につき
      # embed は 1 メッセージなので、投稿成功ごとに累計送信件数を yield し、
      # 呼び出し側が送信済み分だけを既読化できるようにする（issue #94）。
      sent = 0
      Post.build(messages).each do |post|
        send_post post
        sent += post.embeds.size
        yield sent
      end
    end

    private def send_post(post : Post)
      body = post.to_json
      # 送信ペイロードを記録し、content（セリフ）や description / footer が意図通りか
      # CloudWatch で確認できるようにする（issue #95 の切り分け用）。
      Serverless::Lambda.print_log "discord payload: #{body}"
      headers = HTTP::Headers{"Content-Type" => "application/json"}

      attempt = 0
      loop do
        attempt += 1
        res = @client.post(@uri.request_target, headers: headers, body: body)
        return if res.success?

        # 通知が複数投稿に分割される場合、前半チャンク送信後に後半が 429/5xx で
        # 失敗すると既読化されず、次回実行で前半が重複投稿される。これを避けるため
        # レート制限・一時的な 5xx は Retry-After に従って再送する。
        retryable = res.status.code == 429 || res.status.server_error?
        if retryable && attempt < MAX_SEND_ATTEMPTS
          sleep retry_after(res)
          next
        end

        # 恒久的な失敗時は例外にして既読化を止め、次回実行に委ねる。
        raise "discord webhook returned #{res.status_code}: #{res.body}"
      end
    end

    private def retry_after(res : HTTP::Client::Response) : Time::Span
      seconds = res.headers["Retry-After"]?.try(&.to_f?) || 1.0
      seconds.seconds.clamp(Time::Span.zero, MAX_RETRY_WAIT)
    end
  end
end
