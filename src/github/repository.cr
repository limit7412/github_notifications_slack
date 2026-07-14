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
    # ページング中に新着通知が入るとオフセットがずれ前ページ末尾の取りこぼしが
    # 起きるため、取得開始時刻を上限（before）に固定してページ集合を安定させる。
    # 上限より新しい通知は取得対象から外れるが、次回実行で取得される。
    #
    # 取得しきれない場合（途中ページの一時失敗 5xx/401、またはページ数上限到達）は、
    # 不完全な取得状態で既読化して取りこぼすのを避けるため、その実行を丸ごと
    # スキップして次回に委ねる。
    def find_notifications_unread : Array(Notification)
      notifications = [] of Notification
      before = Time.utc
      complete = false

      (1..MAX_PAGES).each do |page|
        params = URI::Params.build do |form|
          form.add "per_page", PER_PAGE.to_s
          form.add "page", page.to_s
          form.add "before", before.to_rfc3339
        end
        res = @github.get "/notifications?#{params}"
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

        # 最終ページ（取得件数が上限未満）に達したら取得完了。
        if page_items.size < PER_PAGE
          complete = true
          break
        end
      end

      # 全ページを取得しきる前に上限に達した場合、未取得の古い通知を
      # last_read_at で巻き込み既読化しないよう、この実行はスキップする。
      unless complete
        Serverless::Lambda.print_log "reached MAX_PAGES(#{MAX_PAGES}) without exhausting notifications; skip this run to avoid marking unfetched older notifications as read"
        return [] of Notification
      end

      notifications
    end

    # コメント取得に失敗した場合に本文へ出す表示用文言。内部エラー文字列を
    # 通知に晒さず、詳細はログのみに残す（issue #96）。
    COMMENT_FETCH_FAILED = "（本文を取得できませんでした）"

    def find_comment_by_url(url : String) : Comment
      Serverless::Lambda.print_log "comment url: #{url}"
      # コメントが無い通知（CI 完了など）。本文は付けず title / リンクで対象を示す。
      if url.blank?
        return Comment.new nil
      end

      res = @github.get url
      if res.status.server_error?
        Serverless::Lambda.print_log "return 5xx error from comments api"
        return Comment.new COMMENT_FETCH_FAILED
      elsif res.status.client_error?
        Serverless::Lambda.print_log "return 4xx error from comments api: #{res.body}"
        return Comment.new COMMENT_FETCH_FAILED
      end

      begin
        Serverless::Lambda.print_log "comment body: #{res.body}"
        Comment.from_json res.body
      rescue
        Serverless::Lambda.print_log "failed parse comment data"
        Comment.new COMMENT_FETCH_FAILED
      end
    end

    # 通知を既読化する。last_read_at を渡すと、その時刻以前に更新された通知
    # だけを既読化する（それ以降に更新された通知は未読のまま残る）。分割送信で
    # 送信済みチャンクまでを都度既読化し、途中失敗時の重複投稿を防ぐのに使う。
    # 省略時は現在時刻までの全通知を既読化する。
    def notification_to_read(last_read_at : Time? = nil)
      res =
        if last_read_at
          # JSON ボディを送るため Content-Type を明示する。無いと GitHub 側で
          # ボディが解析されず last_read_at が無視される恐れがある。
          headers = HTTP::Headers{"Content-Type" => "application/json"}
          body = {last_read_at: last_read_at.to_utc}.to_json
          @github.put "/notifications", headers: headers, body: body
        else
          @github.put "/notifications"
        end

      # 分割送信の重複防止は「送信済みチャンクまでが既読化されている」ことに
      # 依存する。既読化が失敗したまま後続チャンクの送信を続けると、送信済み
      # なのに未既読のチャンクができ、その後の送信失敗時にそれだけが次回重複
      # 投稿される。失敗時は例外にして送信を止め、次回実行に委ねる。
      unless res.success?
        raise "notifications read api returned #{res.status_code}: #{res.body}"
      end
    end
  end
end
