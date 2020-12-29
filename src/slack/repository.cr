require "json"
require "uri"
require "http/client"
require "./models"

class Slack
  def initialize(@url : String)
    @uri = URI.parse @url
  end

  private def send_post(post : SlackPost)
    HTTP::Client.post(@uri,
      body: post.to_json
    )
  end

  def send_attachment(attachment : SlackAttachment)
    post = SlackPost.new [attachment]
    send_post post
  end

  def send_attachments(attachments : Array(SlackAttachment))
    post = SlackPost.new attachments
    send_post post
  end
end
