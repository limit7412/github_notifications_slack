require "../github/repository"
require "../github/usecase"
require "./repository"

module Notify
  class Usecase
    def initialize(
      @github_repo : Github::NotificationRepository,
      @github_uc : Github::Usecase,
      @poster : Notify::PostRepository,
    )
    end

    def check_notifications
      # 取得スナップショット。取得フィルタ（before）と全件送信後の既読化境界
      # （last_read_at）に同じ値を使うことで、取得・送信した集合と既読化される
      # 集合を一致させる（issue #100）。
      # 秒に切り詰めるのは、両者の一致をシリアライズ精度（現状はどちらも秒単位の
      # RFC 3339）に依存させないため。サブセカンドの解釈差による取りこぼしを
      # 構造的に防ぐ。
      fetched_at = Time.utc.at_beginning_of_second

      # updated_at 昇順にソートしてから送信することで、送信済み分を
      # last_read_at で都度既読化できるようにする（issue #94）。
      notifications = @github_repo
        .find_notifications_unread(fetched_at)
        .sort_by(&.updated_at)

      return {msg: "ok"} if notifications.empty?

      # pretext は reason（なぜ通知されたか）を反映した文言になる（issue #96）。
      notices = notifications.map { |item| @github_uc.build_message item }

      # チャンク送信が成功するたび、そこまでに送信済みの通知だけを既読化する。
      # 途中で失敗しても送信済み分は既読化済みなので、未送信分だけが次回
      # 再取得され、前半チャンクの重複投稿が起きない。
      @poster.send_messages(notices) do |sent_count|
        mark_read_through notifications, sent_count, fetched_at
      end

      {msg: "ok"}
    end

    # 昇順ソート済み notifications の先頭 sent_count 件（＝送信済み）までを既読化する。
    #
    # PUT /notifications の last_read_at は排他的境界で、updated_at < last_read_at
    # のスレッドだけが既読化される（等値は未読のまま残る。issue #100 で実 API
    # 検証済み）。これを前提に境界を選ぶ:
    # - 未送信が残る場合: 境界は未送信先頭の updated_at。排他的なので未送信先頭
    #   自身は巻き込まれず、それより前に更新された送信済みは全て既読化される。
    #   同一秒がチャンク境界を跨いだ送信済み分は未読に残り次回再送される
    #   （稀な重複を許容して通知ロストを避ける）
    # - 全件送信済みの場合: 境界は取得スナップショット fetched_at。送信済み最新の
    #   updated_at を境界にすると排他的比較でその通知自身が既読化されず毎分再送
    #   され続けるため（issue #100 の症状）、取得フィルタと同じ fetched_at まで
    #   進める。スナップショット以降の新着は未読のまま次回取得される
    private def mark_read_through(notifications : Array(Github::Notification), sent_count : Int32, fetched_at : Time)
      return if sent_count <= 0

      # sent_count は poster 実装（外部境界）から渡るため、通知件数で丸めて
      # 想定外の値でも安全に扱えるようにする。
      sent_count = {sent_count, notifications.size}.min
      next_unsent = notifications[sent_count]?

      last_read_at = next_unsent.try(&.updated_at) || fetched_at
      @github_repo.notification_to_read last_read_at
    end
  end
end
