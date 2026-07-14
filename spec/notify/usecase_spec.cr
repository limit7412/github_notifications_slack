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

# HTTP を張らずに済むよう find_* を差し替え、既読化呼び出しと取得スナップ
# ショット（before）を記録するリポジトリ。
private class FakeNotificationRepo < Github::NotificationRepository
  getter read_calls = [] of Time?
  getter before_arg : Time?

  # raise_read_after 回目の既読化呼び出しで例外を投げ、既読化失敗を再現する。
  def initialize(@notifications : Array(Github::Notification), @raise_read_after : Int32? = nil)
    super("token")
  end

  def find_notifications_unread(before : Time) : Array(Github::Notification)
    @before_arg = before
    @notifications
  end

  def find_comment_by_url(url : String) : Github::Comment
    Github::Comment.new "body"
  end

  def notification_to_read(last_read_at : Time? = nil)
    @read_calls << last_read_at
    if (limit = @raise_read_after) && @read_calls.size >= limit
      raise "read failed"
    end
  end
end

# chunk_sizes で指定した件数ごとに送信成功を模し、累計件数を yield する。
# fail_at 番目（0 始まり）のチャンク送信で例外を投げて途中失敗を再現する。
private class ChunkPoster < Notify::PostRepository
  getter sent_chunks = 0

  def initialize(@chunk_sizes : Array(Int32), @fail_at : Int32? = nil)
  end

  def send_messages(messages : Array(Notify::Message), & : Int32 ->)
    sent = 0
    @chunk_sizes.each_with_index do |size, i|
      raise "send failed" if @fail_at == i
      sent += size
      @sent_chunks += 1
      yield sent
    end
  end
end

private def run(notifications, poster, &)
  repo = FakeNotificationRepo.new notifications
  usecase = Notify::Usecase.new repo, Github::Usecase.new(repo), poster
  yield usecase
  repo
end

describe Notify::Usecase do
  describe "#check_notifications" do
    # last_read_at は排他的境界（updated_at < last_read_at のみ既読化、issue #100）
    # のため、中間チャンクは「未送信先頭の updated_at」、最終チャンクは
    # 「取得スナップショット」を境界にする。

    it "中間チャンクは未送信先頭の updated_at、最終チャンクは取得スナップショットを境界にする" do
      notifications = [notif("2026-01-01T00:00:01Z"), notif("2026-01-01T00:00:02Z"), notif("2026-01-01T00:00:03Z")]
      repo = run(notifications, ChunkPoster.new([1, 1, 1])) do |usecase|
        usecase.check_notifications
      end
      # 送信済み最新の updated_at (t(3)) を境界にすると排他的比較で t(3) 自身が
      # 既読化されず毎分再送されるため、最終境界は取得スナップショットまで進める。
      repo.read_calls.should eq [t(2), t(3), repo.before_arg]
    end

    it "途中失敗時は送信済みチャンクまでしか既読化しない" do
      notifications = [notif("2026-01-01T00:00:01Z"), notif("2026-01-01T00:00:02Z"), notif("2026-01-01T00:00:03Z")]
      repo = run(notifications, ChunkPoster.new([1, 1, 1], fail_at: 2)) do |usecase|
        expect_raises(Exception, "send failed") { usecase.check_notifications }
      end
      # t(3) は未送信のまま。境界は t(3)（排他的なので t(3) 自身は既読化されず、
      # 次回 t(3) だけが再取得され重複しない）。
      repo.read_calls.should eq [t(2), t(3)]
    end

    it "未送信通知と同一タイムスタンプの通知を巻き込んで既読化しない" do
      # 先頭 2 件が同時刻。チャンク境界がその間に落ちても、境界 t(1) は排他的
      # なので未送信側の t(1) は既読化されない（送信済み側の t(1) も未読に残り
      # 次回再送されるが、ロストよりも稀な重複を許容する）。
      notifications = [notif("2026-01-01T00:00:01Z"), notif("2026-01-01T00:00:01Z"), notif("2026-01-01T00:00:02Z")]
      repo = run(notifications, ChunkPoster.new([1, 1, 1])) do |usecase|
        usecase.check_notifications
      end
      repo.read_calls.should eq [t(1), t(2), repo.before_arg]
    end

    it "取得時と既読化時で同じスナップショットを使う" do
      notifications = [notif("2026-01-01T00:00:01Z")]
      repo = run(notifications, ChunkPoster.new([1])) do |usecase|
        usecase.check_notifications
      end
      repo.before_arg.should_not be_nil
      repo.read_calls.should eq [repo.before_arg]
    end

    it "通知が無ければ既読化しない" do
      repo = run([] of Github::Notification, ChunkPoster.new([] of Int32)) do |usecase|
        usecase.check_notifications
      end
      repo.read_calls.should be_empty
    end

    it "既読化に失敗したら後続チャンクの送信を止める" do
      notifications = [notif("2026-01-01T00:00:01Z"), notif("2026-01-01T00:00:02Z"), notif("2026-01-01T00:00:03Z")]
      poster = ChunkPoster.new([1, 1, 1])
      # 2 回目の既読化で失敗させる。
      repo = FakeNotificationRepo.new notifications, raise_read_after: 2
      usecase = Notify::Usecase.new repo, Github::Usecase.new(repo), poster

      expect_raises(Exception, "read failed") { usecase.check_notifications }

      # 2 チャンク送信後の既読化で失敗 → 3 チャンク目は送信されない。
      poster.sent_chunks.should eq 2
    end
  end
end
