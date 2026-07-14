require "../spec_helper"
require "../../src/github/repository"
require "../../src/github/usecase"
require "../../src/notify/repository"
require "../../src/notify/usecase"

# updated_at だけを差し替えられる通知を組み立てる。
private def notif(updated_at : String, reason = "subscribed")
  Github::Notification.from_json({
    reason:     reason,
    subject:    {type: "Issue", title: "title"},
    repository: {owner: {login: "octocat"}},
    updated_at: updated_at,
  }.to_json)
end

private def t(sec : Int32)
  Time.utc(2026, 1, 1, 0, 0, sec)
end

# HTTP を張らずに済むよう find_* を差し替え、既読化呼び出しを記録するリポジトリ。
private class FakeNotificationRepo < Github::NotificationRepository
  getter read_calls = [] of Time?

  def initialize(@notifications : Array(Github::Notification))
    super("token")
  end

  def find_notifications_unread : Array(Github::Notification)
    @notifications
  end

  def find_comment_by_url(url : String) : Github::Comment
    Github::Comment.new "body"
  end

  def notification_to_read(last_read_at : Time? = nil)
    @read_calls << last_read_at
  end
end

# chunk_sizes で指定した件数ごとに送信成功を模し、累計件数を yield する。
# fail_at 番目（0 始まり）のチャンク送信で例外を投げて途中失敗を再現する。
private class ChunkPoster < Notify::PostRepository
  def initialize(@chunk_sizes : Array(Int32), @fail_at : Int32? = nil)
  end

  def send_messages(messages : Array(Notify::Message), & : Int32 ->)
    sent = 0
    @chunk_sizes.each_with_index do |size, i|
      raise "send failed" if @fail_at == i
      sent += size
      yield sent
    end
  end
end

private def run(notifications, poster, &)
  repo = FakeNotificationRepo.new notifications
  usecase = Notify::Usecase.new repo, Github::Usecase.new(repo), poster
  yield usecase
  repo.read_calls
end

describe Notify::Usecase do
  describe "#check_notifications" do
    it "全チャンク送信成功時は最後に最大 updated_at まで既読化する" do
      notifications = [notif("2026-01-01T00:00:01Z"), notif("2026-01-01T00:00:02Z"), notif("2026-01-01T00:00:03Z")]
      read_calls = run(notifications, ChunkPoster.new([1, 1, 1])) do |usecase|
        usecase.check_notifications
      end
      read_calls.should eq [t(1), t(2), t(3)]
    end

    it "途中失敗時は送信済みチャンクまでしか既読化しない" do
      notifications = [notif("2026-01-01T00:00:01Z"), notif("2026-01-01T00:00:02Z"), notif("2026-01-01T00:00:03Z")]
      read_calls = run(notifications, ChunkPoster.new([1, 1, 1], fail_at: 2)) do |usecase|
        expect_raises(Exception, "send failed") { usecase.check_notifications }
      end
      # 03 は未送信のまま。既読化は 02 まで（次回に 03 だけ再取得され重複しない）。
      read_calls.should eq [t(1), t(2)]
    end

    it "未送信通知と同一タイムスタンプまで巻き込んで既読化しない" do
      # 先頭 2 件が同時刻。チャンク境界がその間に落ちても 01 は既読化しない。
      notifications = [notif("2026-01-01T00:00:01Z"), notif("2026-01-01T00:00:01Z"), notif("2026-01-01T00:00:02Z")]
      read_calls = run(notifications, ChunkPoster.new([1, 1, 1])) do |usecase|
        usecase.check_notifications
      end
      # 1 チャンク目（01 が 1 件のみ送信済み）の直後は、未送信側にも 01 が
      # 残るため既読化をスキップ。2 チャンク目以降で安全に前進する。
      read_calls.should eq [t(1), t(2)]
    end

    it "通知が無ければ既読化しない" do
      read_calls = run([] of Github::Notification, ChunkPoster.new([] of Int32)) do |usecase|
        usecase.check_notifications
      end
      read_calls.should be_empty
    end
  end
end
