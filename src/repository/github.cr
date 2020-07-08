require "uri"
require "http/client"
require "../models"
require "../handler"

class Github
  def initialize(@token : String)
    uri = URI.parse "https://api.github.com"
    @github = HTTP::Client.new uri

    @github.before_request do |request|
      request.headers["Authorization"] = "token #{@token}"
    end
  end

  def get_notifications : Array(GithubNotifications)
    # res = @github.get "/notifications?all=true&since=2019-09-07T23:39:01Z"
    res = @github.get "/notifications"
    Lambda.print_log "notifications body: #{res.body}"

    return Array(GithubNotifications).from_json res.body
  end

  def get_comment(subject : GithubSubject) : GithubComment
    url = !subject.latest_comment_url.blank? ? subject.latest_comment_url : subject.url
    Lambda.print_log "comment url: #{url}"
    if url == ""
      comment = GithubComment.from_json %({
        "user": {},
        "body": "no comments exist"
      })
    end

    res = @github.get url

    begin
      Lambda.print_log "comment body: #{res.body}"
      GithubComment.from_json res.body
    rescue
      Lambda.print_log "faild parse comment data"
      GithubComment.from_json %({
        "user": {},
        "body": "faild parse comment data"
      })
    end
  end

  def notification_to_read
    @github.put "/notifications"
  end
end
