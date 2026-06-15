require "json"
require "uri"
require "http/client"
require "./models"

module Slack
  class PostRepository
    def initialize(url : String)
      @uri = URI.parse url
    end

    def send_attachment(attachment : Attachment)
      send_attachments [attachment]
    end

    def send_attachments(attachments : Array(Attachment))
      send_post Post.new(attachments)
    end

    private def send_post(post : Post)
      HTTP::Client.post(@uri, body: post.to_json)
    end
  end
end
