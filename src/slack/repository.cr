require "json"
require "uri"
require "http/client"
require "./models"
require "../notify/models"
require "../notify/repository"

module Slack
  class PostRepository < Notify::PostRepository
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
      @client.post(@uri.request_target, body: post.to_json)
    end
  end
end
