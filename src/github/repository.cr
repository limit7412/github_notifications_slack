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

    def find_notifications_unread : Array(Notification)
      res = @github.get "/notifications"
      if res.status.server_error?
        Serverless::Lambda.print_log "return 5xx error from notifications api"
        return [] of Notification
      elsif res.status.unauthorized?
        # GitHub が断続的に 401 を返すことがあるため、毎分の次回実行に任せてスキップする。
        # トークン失効などの恒久的な 401 までサイレントに握りつぶす点は本来リトライや
        # 連続失敗の監視で区別すべきだが、個人用途の通知ツールであり実装コストに
        # 見合わないため割り切る。
        Serverless::Lambda.print_log "return 401 error from notifications api, skip"
        return [] of Notification
      elsif res.status.client_error?
        Serverless::Lambda.print_log "return 4xx error from notifications api"
        err = Error.from_json res.body
        raise "notifications api return client error: #{err.message}"
      end

      Serverless::Lambda.print_log "notifications body: #{res.body}"
      Array(Notification).from_json(res.body)
    end

    def find_comment_by_url(url : String) : Comment
      Serverless::Lambda.print_log "comment url: #{url}"
      if url.blank?
        return Comment.new "no comments exist"
      end

      res = @github.get url
      if res.status.server_error?
        Serverless::Lambda.print_log "return 5xx error from comments api"
        return Comment.new "comments api return server error"
      elsif res.status.client_error?
        Serverless::Lambda.print_log "return 4xx error from comments api"
        err = Error.from_json res.body
        return Comment.new "comments api return client error: #{err.message}"
      end

      begin
        Serverless::Lambda.print_log "comment body: #{res.body}"
        Comment.from_json res.body
      rescue
        Serverless::Lambda.print_log "failed parse comment data"
        Comment.new "failed parse comment data"
      end
    end

    def notification_to_read
      @github.put "/notifications"
    end
  end
end
