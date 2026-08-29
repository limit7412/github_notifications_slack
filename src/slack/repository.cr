require "json"
require "uri"
require "http/client"
require "./models"
require "../notify/models"
require "../notify/repository"

module Slack
  class PostRepository < Notify::PostRepository
    MAX_SEND_ATTEMPTS = 3         # 送信リトライ回数の上限
    MAX_RETRY_WAIT    = 5.seconds # Retry-After の待機上限

    def initialize(url : String)
      @uri = URI.parse url
      @client = HTTP::Client.new @uri
    end

    def send_messages(messages : Array(Notify::Message), & : Int32 ->)
      # Slack は全 attachments を 1 投稿で送るため atomic。送信成功後に
      # 全件をまとめて既読化できるよう、累計件数を一度だけ yield する。
      send_post Post.build(messages)
      yield messages.size
    end

    private def send_post(post : Post)
      body = post.to_json

      attempt = 0
      loop do
        attempt += 1
        res = post_json body
        return if res.success?

        # 重要度で投稿を分けるようになり、1 実行あたりの投稿数が増えてレート制限
        # （429）に当たりやすくなった（issue #120）。一時的な失敗でその実行を丸ごと
        # 落とさずに済むよう、429 と 5xx は Retry-After に従って再送する。
        # 方針は Discord::PostRepository と揃えている。
        retryable = res.status.code == 429 || res.status.server_error?
        if retryable && attempt < MAX_SEND_ATTEMPTS
          sleep retry_after(res)
          next
        end

        # 応答を捨てると、投稿されていない通知まで呼び出し側が既読化してしまい、
        # その通知はどこにも表示されないまま消える。恒久的な失敗は例外にして
        # 既読化を止め、次回実行に委ねる。
        raise "slack webhook returned #{res.status_code}: #{res.body}"
      end
    end

    private def post_json(body : String) : HTTP::Client::Response
      @client.post(@uri.request_target, body: body)
    end

    private def retry_after(res : HTTP::Client::Response) : Time::Span
      seconds = res.headers["Retry-After"]?.try(&.to_f?) || 1.0
      seconds.seconds.clamp(Time::Span.zero, MAX_RETRY_WAIT)
    end
  end
end
