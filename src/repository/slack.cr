require "json"
require "uri"
require "http/client"

class Slack
  def initialize(@url : String)
    @uri = URI.parse @url
  end

  def send_post(post)
    body = {
      attachments: [post],
    }

    HTTP::Client.post(@uri,
      body: body.to_json
    )
  end
end
