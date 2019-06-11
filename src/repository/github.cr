require "uri"
require "http/client"

class Github
  def initialize(@username : String, @token : String)
    uri = URI.parse "https://api.github.com"
    @github = HTTP::Client.new uri

    @github.basic_auth @username, @token
  end

  def get_notifications
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

  def get_comment(url : String)
    res = @github.get url

    if !res["user"].nil?
      author_name = res["user"]["login"]
      author_icon = res["user"]["avatar_url"]
      author_link = res["user"]["html_url"]
    end

    return {
      author_name: author_name,
      author_icon: author_icon,
      author_link: author_link,
      title_link:  res["html_url"],
      body:        res["body"],
    }
  end

  def notification_to_read
    res = @github.put "/notifications"
  end
end
