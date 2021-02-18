require "uri"
require "http/client"
require "./models"
require "../runtime/lambda"

module Github
  class NotificationRepository
    def initialize(@token : String)
      uri = URI.parse "https://api.github.com"
      @github = HTTP::Client.new uri

      @github.before_request do |request|
        request.headers["Authorization"] = "token #{@token}"
      end
    end

    def get_notifications : Array(Notifications)
      res = @github.get "/notifications"
      if res.status_code >= 500
        Lambda.print_log "return server error from api"
        Array(Notifications).new
      end

      Lambda.print_log "notifications body: #{res.body}"

      Array(Notifications)
        .from_json(res.body)
        .map do |item|
          item.comment = get_comment item.subject.comment_url
          item
        end
    end

    private def get_comment(url : String) : Comment
      Lambda.print_log "comment url: #{url}"
      if url.blank?
        Comment.from_json %({
        "user": {},
        "body": "no comments exist"
      })
      end

      res = @github.get url
      if res.status_code >= 500
        Lambda.print_log "return server error from api"
        Comment.from_json %({
        "user": {},
        "body": "github api retrun server error"
      })
      end

      begin
        Lambda.print_log "comment body: #{res.body}"
        Comment.from_json res.body
      rescue
        Lambda.print_log "faild parse comment data"
        Comment.from_json %({
        "user": {},
        "body": "faild parse comment data"
      })
      end
    end

    def notification_to_read
      @github.put "/notifications"
    end
  end
end
