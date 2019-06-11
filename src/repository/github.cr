require "uri"
require "http/client"

class Github
  def initialize(@username : String, @token : String)
    uri = URI.parse "https://api.github.com"
    @github = HTTP::Client.new uri
  end

  def get_notifications
    @github.basic_auth @username, @token

    res = @github.get "/notifications?all=true&since=2018-09-07T23:39:01Z"
    # res = @github.get "/notifications"

    result = JSON.parse(res.body).as_a

    return result.map { |line| {
      type:             line["subject"]["type"],
      reason:           line["reason"],
      repository_name:  line["repository"]["full_name"],
      title:            line["subject"]["title"],
      title_link:       line["repository"]["html_url"],
      avatar:           line["repository"]["owner"]["avatar_url"],
      comment_url:      line["subject"]["url"],
      latest_url:       line["subject"]["latest_comment_url"],
      subscription_url: line["subscription_url"],
    } }
  end
end
