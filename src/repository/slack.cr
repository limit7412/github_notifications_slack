require "json"
require "uri"
require "openssl"

class Slack
  def initialize(@url : String)
    @uri = URI.parse @url
  end

  def send_post(message : String, title : String, text : String, color : String, slack_id : String)
    post = {
      fallback: message,
      pretext:  "<@#{slack_id}> #{message}",
      title:    title,
      text:     text,
      color:    color,
      footer:   "limit7412/new_channel_notify_slack",
    }
    body = {
      attachments: [post],
    }

    HTTP::Client.post(@uri,
      body: body.to_json
    )

    return error.message
  end
end
