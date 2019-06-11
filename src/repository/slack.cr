require "json"
require "uri"
require "http/client"

class Slack
  def initialize(@url : String)
    @uri = URI.parse @url
  end

  def send_post(message, title, text, color : String, slack_id : String, is_mention : Boolian)
    mention = is_mention ? "<@#{slack_id}> " : ""
    post = {
      fallback: message,
      pretext:  "#{mention}#{message}",
      title:    title,
      text:     text,
      color:    color,
      footer:   "limit7412/github_notifications_slack",
    }
    body = {
      attachments: [post],
    }

    HTTP::Client.post(@uri,
      body: body.to_json
    )
  end
end
