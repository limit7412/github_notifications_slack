require "uri"
require "http/client"
require "../models"

class Github
  def initialize(@username : String, @token : String)
    uri = URI.parse "https://api.github.com"
    @github = HTTP::Client.new uri

    @github.basic_auth @username, @token
  end

  def get_notifications
    res = @github.get "/notifications?all=true&since=2019-09-07T23:39:01Z"
    # res = @github.get "/notifications"

    result = JSON.parse(res.body).as_a

    return result.map { |line| {
      type:             line["subject"]["type"].to_s,
      reason:           line["reason"].to_s,
      repository_name:  line["repository"]["full_name"].to_s,
      title:            line["subject"]["title"].to_s,
      title_link:       line["repository"]["html_url"].to_s,
      avatar:           line["repository"]["owner"]["avatar_url"].to_s,
      comment_url:      line["subject"]["url"].to_s,
      latest_url:       line["subject"]["latest_comment_url"].to_s,
      subscription_url: line["subscription_url"].to_s,
    } }
  end

  def get_comment(url : String)
    res = @github.get url
    if res.status.ok?
      result = GithubComment.from_json(res.body)

      {
        name:        result.user.login,
        icon:        result.user.avatar_url,
        author_link: result.user.html_url,
        title_link:  result.html_url,
        body:        result.body,
      }
    else
      {
        name:        "",
        icon:        "",
        author_link: "",
        title_link:  "",
        body:        "",
      }
    end
  end

  def notification_to_read
    # res = @github.put "/notifications"
  end
end
