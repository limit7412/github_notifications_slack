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

    result = Array(GithubNotifications).from_json res.body

    return result.map { |line| {
      type:             line.subject.type,
      reason:           line.reason,
      repository_name:  line.repository.full_name,
      title:            line.subject.title,
      title_link:       line.repository.html_url,
      avatar:           line.repository.owner.avatar_url,
      comment_url:      line.subject.url,
      latest_url:       line.subject.latest_comment_url,
      subscription_url: line.subscription_url,
    } }
  end

  def get_comment(url : String) : GithubComment
    res = @github.get url

    if res.status.ok?
      GithubComment.from_json res.body
    else
      GithubComment.from_json %({
        "user": {}
      })
    end
  end

  def notification_to_read
    # res = @github.put "/notifications"
  end
end
