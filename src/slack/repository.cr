require "json"
require "./models"
require "../notify/models"
require "../notify/repository"
require "../webhook/client"

module Slack
  class PostRepository < Notify::PostRepository
    def initialize(url : String)
      @webhook = Webhook::Client.new "slack", url
    end

    def initialize(@webhook : Webhook::Client)
    end

    def send_messages(messages : Array(Notify::Message), & : Int32 ->)
      # Slack は全 attachments を 1 投稿で送るため atomic。送信成功後に
      # 全件をまとめて既読化できるよう、累計件数を一度だけ yield する。
      # 送信に失敗すると Webhook::Client が例外にするので、yield には到達しない。
      @webhook.post Post.build(messages).to_json
      yield messages.size
    end
  end
end
