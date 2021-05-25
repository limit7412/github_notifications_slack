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

    def find_notifications_unread : Array(Notifications)
      res = @github.get "/notifications"
      if res.status_code >= 500
        Serverless::Lambda.print_log "return 5xx error from notifications api"
        return Array(Notifications).new
      elsif res.status_code >= 400
        Serverless::Lambda.print_log "return 4xx error from notifications api"
        err = Error.from_json res.body
        raise "notifications api retrun client error: #{err.message}"
      end

      Serverless::Lambda.print_log "notifications body: #{res.body}"
      Array(Notifications).from_json(res.body)
    end

    def find_comment_by_url(url : String) : Comment
      Serverless::Lambda.print_log "comment url: #{url}"
      if url.blank?
        return Comment.new "no comments exist"
      end

      res = @github.get url
      if res.status_code >= 500
        Serverless::Lambda.print_log "return 5xx error from comments api"
        return Comment.new "comments api retrun server error"
      elsif res.status_code >= 400
        Serverless::Lambda.print_log "return 4xx error from comments api"
        err = Error.from_json res.body
        return Comment.new "comments api retrun client error: #{err.message}"
      end

      begin
        Serverless::Lambda.print_log "comment body: #{res.body}"
        Comment.from_json res.body
      rescue
        Serverless::Lambda.print_log "faild parse comment data"
        Comment.new "faild parse comment data"
      end
    end

    def notification_to_read
      @github.put "/notifications"
    end
  end
end
