require "json"
require "uri"
require "http/client"
require "./models"

module Slack
  class PostRepository
    def initialize(@url : String)
      @uri = URI.parse @url
    end

    private def send_post(post : Post)
      HTTP::Client.post(@uri,
        body: post.to_json
      )
    end

    def send_attachment(attachment : Attachment)
      post = Post.new [attachment]
      send_post post
    end

    def send_attachments(attachments : Array(Attachment))
      post = Post.new attachments
      send_post post
    end
  end
end
