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

    return Array(GithubNotifications).from_json res.body
  end

  def get_comment(subject : GithubSubject) : GithubComment
    url = !subject.latest_comment_url.blank? ? subject.latest_comment_url : subject.url
    res = @github.get url

    if res.status.ok?
      GithubComment.from_json res.body
    else
      GithubComment.from_json %({
        "user": {},
        "body": "no comment data"
      })
    end
  end

  def notification_to_read
    # res = @github.put "/notifications"
  end
end
