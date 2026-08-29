require "json"
require "./models"
require "../notify/models"
require "../notify/repository"
require "../runtime/lambda"
require "../webhook/client"

module Discord
  class PostRepository < Notify::PostRepository
    def initialize(url : String)
      @webhook = Webhook::Client.new "discord", url
    end

    def initialize(@webhook : Webhook::Client)
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
      @webhook.post body
    end
  end
end
