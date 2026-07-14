require "uri"
require "http/client"
require "./models"
require "../runtime/lambda"

module Github
  class NotificationRepository
    PER_PAGE  = 100 # GitHub /notifications の per_page 上限
    MAX_PAGES =  20 # 暴走防止の取得ページ数上限（= 最大 2000 件）

    def initialize(@token : String)
      uri = URI.parse "https://api.github.com"
      @github = HTTP::Client.new uri

      @github.before_request do |request|
        request.headers["Authorization"] = "token #{@token}"
      end
    end

    # 未読通知を全ページ取得する。
    #
    # /notifications はページングされ既定では 1 ページ分（最新側）しか返さない。
    # 一部ページだけを取得した状態で last_read_at 既読化を行うと、未取得の
    # 古い通知（＝更新時刻が小さくチャンク送信対象外）まで last_read_at 以前と
    # して既読化され、未送信のまま消えてしまう。これを防ぐため全ページを
    # 取得してから境界を決める必要がある（issue #94 / PR #97 レビュー指摘）。
    #
    # 途中ページで一時的な失敗（5xx / 401）が起きた場合は、取得済みが不完全な
    # まま既読化して取りこぼすのを避けるため、その実行は丸ごとスキップして
    # 次回に委ねる。
    def find_notifications_unread : Array(Notification)
      notifications = [] of Notification

      (1..MAX_PAGES).each do |page|
        res = @github.get "/notifications?per_page=#{PER_PAGE}&page=#{page}"
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

        Serverless::Lambda.print_log "notifications body (page #{page}): #{res.body}"
        page_items = Array(Notification).from_json(res.body)
        notifications.concat page_items

        # 最終ページ（取得件数が上限未満）に達したら終了。
        break if page_items.size < PER_PAGE

        if page == MAX_PAGES
          Serverless::Lambda.print_log "reached MAX_PAGES(#{MAX_PAGES}); remaining older notifications are deferred to next run"
        end
      end

      notifications
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

    # 通知を既読化する。last_read_at を渡すと、その時刻以前に更新された通知
    # だけを既読化する（それ以降に更新された通知は未読のまま残る）。分割送信で
    # 送信済みチャンクまでを都度既読化し、途中失敗時の重複投稿を防ぐのに使う。
    # 省略時は現在時刻までの全通知を既読化する。
    def notification_to_read(last_read_at : Time? = nil)
      if last_read_at
        # JSON ボディを送るため Content-Type を明示する。無いと GitHub 側で
        # ボディが解析されず last_read_at が無視される恐れがある。
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        body = {last_read_at: last_read_at.to_utc}.to_json
        @github.put "/notifications", headers: headers, body: body
      else
        @github.put "/notifications"
      end
    end
  end
end
