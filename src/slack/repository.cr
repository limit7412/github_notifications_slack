require "json"
require "uri"
require "http/client"
require "./models"
require "../notify/models"
require "../notify/repository"

module Slack
  class PostRepository < Notify::PostRepository
    def initialize(url : String, @mention_id : String)
      @uri = URI.parse url
      @client = HTTP::Client.new @uri
    end

    def send_messages(messages : Array(Notify::Message))
      send_post Post.build(messages, @mention_id)
    end

    private def send_post(post : Post)
      @client.post(@uri.request_target, body: post.to_json)
    end
  end
end
