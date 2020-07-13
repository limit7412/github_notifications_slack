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
    res = @github.get "/notifications"
    if res.status_code >= 500
      Lambda.print_log "return server error from api"
      return Array(GithubNotifications).new
    end

    Lambda.print_log "notifications body: #{res.body}"

    Array(GithubNotifications).from_json res.body
  end

  def get_comment(subject : GithubSubject) : GithubComment
    url = !subject.latest_comment_url.blank? ? subject.latest_comment_url : subject.url
    Lambda.print_log "comment url: #{url}"
    if url.blank?
      return GithubComment.from_json %({
        "user": {},
        "body": "no comments exist"
      })
    end

    res = @github.get url
    if res.status_code >= 500
      Lambda.print_log "return server error from api"
      return GithubComment.from_json %({
        "user": {},
        "body": "faild parse comment data"
      })
    end

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
