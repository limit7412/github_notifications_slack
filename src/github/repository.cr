require "uri"
require "http/client"
require "./models"
require "../runtime/lambda"

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
      Array(GithubNotifications).new
    end

    Lambda.print_log "notifications body: #{res.body}"

    Array(GithubNotifications)
      .from_json(res.body)
      .map do |item|
        item.comment = get_comment item.subject.comment_url
        item
      end
  end

  private def get_comment(url : String) : GithubComment
    Lambda.print_log "comment url: #{url}"
    if url.blank?
      GithubComment.from_json %({
        "user": {},
        "body": "no comments exist"
      })
    end

    res = @github.get url
    if res.status_code >= 500
      Lambda.print_log "return server error from api"
      GithubComment.from_json %({
        "user": {},
        "body": "github api retrun server error"
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
