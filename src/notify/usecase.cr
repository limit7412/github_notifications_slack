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
      # updated_at 昇順にソートしてから送信することで、送信済み分を
      # last_read_at で都度既読化できるようにする（issue #94）。
      notifications = @github_repo
        .find_notifications_unread
        .sort_by(&.updated_at)

      return {msg: "ok"} if notifications.empty?

      notices = notifications.map do |item|
        message =
          if item.subject.update?
            "更新があったみたいです。確認してみましょう！"
          else
            "なにかあったみたいです。確認してみましょう！"
          end
        pretext = "[#{item.subject.type}] #{message}"

        @github_uc.build_message item, pretext
      end

      # チャンク送信が成功するたび、そこまでに送信済みの通知だけを既読化する。
      # 途中で失敗しても送信済み分は既読化済みなので、未送信分だけが次回
      # 再取得され、前半チャンクの重複投稿が起きない。
      @poster.send_messages(notices) do |sent_count|
        mark_read_through notifications, sent_count
      end

      {msg: "ok"}
    end

    # 昇順ソート済み notifications の先頭 sent_count 件（＝送信済み）までを既読化する。
    # last_read_at は「未送信の先頭通知より前の最大 updated_at」に丸める。これにより
    # 未送信通知と同一タイムスタンプの通知まで巻き込んで既読化してしまうのを防ぐ
    # （PUT /notifications は last_read_at 以前に更新された通知を既読化するため）。
    # 送信済みが全て未送信先頭と同時刻の場合は安全に進められる位置が無いのでスキップし、
    # 次回実行に委ねる（稀な重複より通知ロストを避ける）。
    private def mark_read_through(notifications : Array(Github::Notification), sent_count : Int32)
      return if sent_count <= 0

      sent = notifications[0, sent_count]
      next_unsent = notifications[sent_count]?

      last_read_at =
        if next_unsent.nil?
          sent.last.updated_at
        else
          boundary = next_unsent.updated_at
          sent.map(&.updated_at).select(&.<(boundary)).max?
        end

      return if last_read_at.nil?

      @github_repo.notification_to_read last_read_at
    end
  end
end
