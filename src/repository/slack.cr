require "json"
require "uri"
require "http/client"
require "../models/slack"

class Slack
  def initialize(@url : String)
    @uri = URI.parse @url
  end

  def send_post(post : SlackPost)
    HTTP::Client.post(@uri,
      body: post.to_json
    )
  end
end
