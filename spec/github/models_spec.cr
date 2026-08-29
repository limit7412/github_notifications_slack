require "../spec_helper"

private def subject_from(type : String, url = "", latest_comment_url = "")
  Github::Subject.from_json({
    type:               type,
    title:              "title",
    url:                url,
    latest_comment_url: latest_comment_url,
  }.to_json)
end

describe Github::Subject do
  describe "#update?" do
    it "is true for tracked subject types" do
      [
        Github::Subject::Type::PULL_REQUEST,
        Github::Subject::Type::ISSUE,
        Github::Subject::Type::COMMIT,
        Github::Subject::Type::DISCUSSION,
      ].each do |type|
        subject_from(type).update?.should be_true
      end
    end

    it "is false for unknown subject types" do
      subject_from("Release").update?.should be_false
    end
  end

  describe "#color" do
    it "returns a distinct color per known type" do
      subject_from(Github::Subject::Type::PULL_REQUEST).color.should eq "#F6CEE3"
      subject_from(Github::Subject::Type::ISSUE).color.should eq "#A9D0F5"
      subject_from(Github::Subject::Type::COMMIT).color.should eq "#f5d7a9"
      subject_from(Github::Subject::Type::DISCUSSION).color.should eq "#7fffd4"
    end

    it "falls back to a default color for unknown types" do
      subject_from("Release").color.should eq "#D8D8D8"
    end
  end

  describe "#comment_url" do
    it "prefers latest_comment_url when present" do
      subject = subject_from("Issue", url: "u", latest_comment_url: "c")
      subject.comment_url.should eq "c"
    end

    it "falls back to url for body-bearing types when latest_comment_url is blank" do
      subject = subject_from("Issue", url: "u", latest_comment_url: "")
      subject.comment_url.should eq "u"
    end

    it "returns empty for types without a comment body when no comment url is present" do
      # CI 完了通知（CheckSuite）などは subject.url を本文取得に使わない。
      subject_from("CheckSuite", url: "https://api.github.com/repos/o/r/check-suites/1").comment_url.should eq ""
    end

    it "still uses latest_comment_url even for non-body types" do
      subject_from("Commit", url: "u", latest_comment_url: "c").comment_url.should eq "c"
    end

    # Release は subject.url を取得するとリリースノートが返る（issue #121）。
    it "falls back to url for a release when latest_comment_url is blank" do
      subject = subject_from("Release", url: "https://api.github.com/repos/o/r/releases/1")
      subject.comment_url.should eq "https://api.github.com/repos/o/r/releases/1"
    end
  end

  describe "#commented?" do
    it "is true when the thread has a comment" do
      subject = subject_from(
        "PullRequest",
        url: "https://api.github.com/repos/o/r/pulls/1",
        latest_comment_url: "https://api.github.com/repos/o/r/issues/comments/1",
      )
      subject.commented?.should be_true
    end

    it "is false when latest_comment_url mirrors the subject url (no comment yet)" do
      subject = subject_from(
        "PullRequest",
        url: "https://api.github.com/repos/o/r/pulls/1",
        latest_comment_url: "https://api.github.com/repos/o/r/pulls/1",
      )
      subject.commented?.should be_false
    end

    it "is false when latest_comment_url is blank" do
      subject_from("PullRequest", url: "https://api.github.com/repos/o/r/pulls/1").commented?.should be_false
    end
  end

  describe "#number" do
    it "extracts a trailing issue/PR number from the url" do
      subject_from("Issue", url: "https://api.github.com/repos/o/r/issues/42").number.should eq "42"
    end

    it "tolerates a trailing slash" do
      subject_from("Issue", url: "https://api.github.com/repos/o/r/issues/42/").number.should eq "42"
    end

    it "returns nil when the trailing segment is not numeric (e.g. a commit SHA)" do
      subject_from("Commit", url: "https://api.github.com/repos/o/r/commits/abc123").number.should be_nil
    end

    it "returns nil for types whose trailing number is not a GitHub issue/PR number" do
      # Release は末尾が数値 ID でも #番号 表示は誤解を招くため付けない。
      subject_from("Release", url: "https://api.github.com/repos/o/r/releases/5").number.should be_nil
    end

    it "returns nil when the url is blank" do
      subject_from("Issue").number.should be_nil
    end
  end
end

describe Github::Notification do
  describe "#mention?" do
    it "is true for reasons that mention the user" do
      Github::Notification::MENTION_REASONS.each do |reason|
        notification_from(reason).mention?.should be_true
      end
    end

    it "is false for non-mention reasons" do
      notification_from("subscribed").mention?.should be_false
      notification_from("ci_activity").mention?.should be_false
    end
  end

  describe "#reason_message" do
    it "returns a reason-specific message for known reasons" do
      notification_from("review_requested").reason_message.should eq "レビューを依頼されました"
      notification_from("assign").reason_message.should eq "アサインされました"
      notification_from("comment").reason_message.should eq "コメントがつきました"
    end

    it "falls back to a generic message for unknown reasons" do
      notification_from("some_future_reason").reason_message.should eq Github::Notification::GENERIC_MESSAGE
    end

    it "switches to a follow-up message once a review-requested thread has a comment" do
      notification = notification_from(
        "review_requested",
        url: "https://api.github.com/repos/o/r/pulls/1",
        latest_comment_url: "https://api.github.com/repos/o/r/issues/comments/1",
      )
      notification.reason_message.should eq "レビュー依頼中の PR に動きがありました"
    end

    it "switches to a follow-up message once an assigned thread has a comment" do
      notification = notification_from(
        "assign",
        url: "https://api.github.com/repos/o/r/issues/1",
        latest_comment_url: "https://api.github.com/repos/o/r/issues/comments/1",
      )
      notification.reason_message.should eq "担当している PR/Issue に動きがありました"
    end

    it "keeps the assign message while the thread has no comment" do
      notification = notification_from(
        "assign",
        url: "https://api.github.com/repos/o/r/issues/1",
        latest_comment_url: "https://api.github.com/repos/o/r/issues/1",
      )
      notification.reason_message.should eq "アサインされました"
    end

    it "keeps the review-requested message while the thread has no comment" do
      notification = notification_from(
        "review_requested",
        url: "https://api.github.com/repos/o/r/pulls/1",
        latest_comment_url: "https://api.github.com/repos/o/r/pulls/1",
      )
      notification.reason_message.should eq "レビューを依頼されました"
    end

    it "keeps the reason message for reasons without a follow-up variant" do
      notification = notification_from(
        "comment",
        url: "https://api.github.com/repos/o/r/pulls/1",
        latest_comment_url: "https://api.github.com/repos/o/r/issues/comments/1",
      )
      notification.reason_message.should eq "コメントがつきました"
    end

    # latest_comment_url が subject.url に戻る通知でも、取得済みの subject 本体の
    # コメント数で初回でないと判断できる（issue #116）。
    it "switches to a follow-up message when the fetched pull request has conversation comments" do
      message = pull_request_without_comment_signal.reason_message(subject_detail(comments: 2, review_comments: 0))
      message.should eq "担当している PR/Issue に動きがありました"
    end

    it "switches to a follow-up message when the fetched pull request only has review comments" do
      message = pull_request_without_comment_signal.reason_message(subject_detail(comments: 0, review_comments: 3))
      message.should eq "担当している PR/Issue に動きがありました"
    end

    it "switches to a follow-up message when the fetched issue has comments" do
      notification = notification_from(
        "assign",
        url: "https://api.github.com/repos/o/r/issues/1",
        latest_comment_url: "https://api.github.com/repos/o/r/issues/1",
      )
      notification.reason_message(subject_detail(comments: 1)).should eq "担当している PR/Issue に動きがありました"
    end

    it "keeps the assign message when the fetched pull request has no comment at all" do
      message = pull_request_without_comment_signal.reason_message(subject_detail(comments: 0, review_comments: 0))
      message.should eq "アサインされました"
    end

    it "keeps the assign message when the fetched payload carries no comment count" do
      # 本文取得に失敗した場合など、判断材料が無いときは初回向け文言のままにする。
      pull_request_without_comment_signal.reason_message(subject_detail).should eq "アサインされました"
    end
  end

  describe "#pretext" do
    it "prefixes the subject type before the reason message" do
      notification_from("mention").pretext.should eq "[Issue] メンションされました"
    end

    it "passes the fetched subject detail through to the reason message" do
      pretext = pull_request_without_comment_signal.pretext(subject_detail(comments: 1))
      pretext.should eq "[PullRequest] 担当している PR/Issue に動きがありました"
    end
  end

  describe "#display_title" do
    it "formats as owner/repo#number title when a number is present" do
      notification = notification_with(url: "https://api.github.com/repos/octocat/Hello-World/issues/42")
      notification.display_title.should eq "octocat/Hello-World#42 title"
    end

    it "falls back to the bare title when no number is present" do
      notification_with(url: "").display_title.should eq "title"
    end
  end

  describe "#link" do
    it "prefers the comment html_url" do
      comment = Github::Comment.from_json({html_url: "https://example.com/c", user: {} of String => String}.to_json)
      notification_with.link(comment).should eq "https://example.com/c"
    end

    it "falls back to the repository html_url when the comment has no link" do
      comment = Github::Comment.new nil
      notification = notification_with(repo_html_url: "https://github.com/octocat/Hello-World")
      notification.link(comment).should eq "https://github.com/octocat/Hello-World"
    end
  end

  describe "#checks_gated?" do
    it "is true for every pull request notification regardless of reason" do
      # reason は購読理由であってイベント種別ではないため、mention 系も
      # 「今回の更新がメンションだった」ことを意味しない。よって例外にしない。
      [
        "review_requested",
        "assign",
        "author",
        "mention",
        "team_mention",
      ].each do |reason|
        notification_from(reason, type: "PullRequest").checks_gated?.should be_true
      end
    end

    it "is false for non pull request subjects" do
      notification_from("review_requested", type: "Issue").checks_gated?.should be_false
      notification_from("mention", type: "Issue").checks_gated?.should be_false
      notification_from("author", type: "Commit").checks_gated?.should be_false
    end
  end

  it "parses a GitHub notifications API payload" do
    notifications = Array(Github::Notification).from_json(NOTIFICATIONS_FIXTURE)
    notifications.size.should eq 1

    notification = notifications.first
    notification.reason.should eq "mention"
    notification.subject.type.should eq "Issue"
    notification.subject.title.should eq "Spurious failure"
    notification.repository.full_name.should eq "octocat/Hello-World"
    notification.mention?.should be_true
    notification.updated_at.should eq Time.utc(2026, 7, 14, 0, 0, 0)
  end
end

private def notification_from(reason : String, type = "Issue", url = "", latest_comment_url = "")
  Github::Notification.from_json({
    reason:     reason,
    subject:    {type: type, title: "title", url: url, latest_comment_url: latest_comment_url},
    repository: {owner: {login: "octocat"}},
    updated_at: "2026-07-14T00:00:00Z",
  }.to_json)
end

# latest_comment_url が subject.url に戻っている（＝コメントの有無を判定できない）
# アサイン済み PR の通知（issue #116）。
private def pull_request_without_comment_signal
  notification_from(
    "assign",
    type: "PullRequest",
    url: "https://api.github.com/repos/o/r/pulls/1",
    latest_comment_url: "https://api.github.com/repos/o/r/pulls/1",
  )
end

# 本文取得で返る subject 本体（PR / Issue）のレスポンス。件数を省くと
# コメントオブジェクト（件数フィールドを持たない）と同じ形になる。
private def subject_detail(comments : Int32? = nil, review_comments : Int32? = nil)
  Github::Comment.from_json({
    body:            "body",
    user:            {login: "octocat"},
    comments:        comments,
    review_comments: review_comments,
  }.to_json)
end

describe Github::Comment do
  describe "#commented?" do
    it "is true when the pull request has conversation comments" do
      subject_detail(comments: 2, review_comments: 0).commented?.should be_true
    end

    it "is true when the pull request only has review comments" do
      subject_detail(comments: 0, review_comments: 3).commented?.should be_true
    end

    it "is false when the pull request has no comment at all" do
      subject_detail(comments: 0, review_comments: 0).commented?.should be_false
    end

    it "is false when the payload has no comment count (a comment object)" do
      subject_detail.commented?.should be_false
    end

    it "is false for a locally built comment (no comment url / fetch failure)" do
      Github::Comment.new(nil).commented?.should be_false
    end
  end

  # Release の応答は投稿者を author に入れる。user を必須にしていたころは解析ごと
  # 失敗し、本文が「取得できませんでした」に倒れていた（issue #121）。
  describe "#poster" do
    it "parses a release payload and keeps its body" do
      comment = Github::Comment.from_json(release_payload)

      comment.body.should eq "リリースノート本文"
      comment.poster.login.should eq "octocat"
    end

    it "prefers the comment user over the author" do
      json = {user: {login: "commenter"}, author: {login: "releaser"}, body: "b"}.to_json
      Github::Comment.from_json(json).poster.login.should eq "commenter"
    end

    it "falls back to an empty user when the payload has neither" do
      Github::Comment.from_json({body: "b"}.to_json).poster.login.should be_nil
    end

    it "returns an empty user for a locally built comment" do
      Github::Comment.new("b").poster.login.should be_nil
    end
  end
end

# GitHub の Release オブジェクト。投稿者は user ではなく author に入る。
private def release_payload
  {
    url:      "https://api.github.com/repos/o/r/releases/1",
    html_url: "https://github.com/o/r/releases/tag/v1.2.3",
    author:   {login: "octocat", avatar_url: "https://example.com/a.png"},
    tag_name: "v1.2.3",
    name:     "v1.2.3",
    body:     "リリースノート本文",
  }.to_json
end

private def notification_with(url = "", repo_html_url : String? = nil)
  Github::Notification.from_json({
    reason:     "subscribed",
    subject:    {type: "Issue", title: "title", url: url},
    repository: {full_name: "octocat/Hello-World", html_url: repo_html_url, owner: {login: "octocat"}},
    updated_at: "2026-07-14T00:00:00Z",
  }.to_json)
end

describe Github::ChecksState do
  describe "#merge" do
    it "takes the stricter state of the two" do
      Github::ChecksState::Success.merge(Github::ChecksState::Failure).should eq Github::ChecksState::Failure
      Github::ChecksState::Pending.merge(Github::ChecksState::Failure).should eq Github::ChecksState::Failure
      Github::ChecksState::Success.merge(Github::ChecksState::Pending).should eq Github::ChecksState::Pending
      Github::ChecksState::NoChecks.merge(Github::ChecksState::Success).should eq Github::ChecksState::Success
    end

    it "keeps the other state when one side could not be fetched" do
      Github::ChecksState::Unknown.merge(Github::ChecksState::Success).should eq Github::ChecksState::Success
      Github::ChecksState::Failure.merge(Github::ChecksState::Unknown).should eq Github::ChecksState::Failure
    end

    it "stays unknown when neither side could be fetched" do
      Github::ChecksState::Unknown.merge(Github::ChecksState::Unknown).should eq Github::ChecksState::Unknown
    end

    it "stays no-checks when neither side has any check" do
      Github::ChecksState::NoChecks.merge(Github::ChecksState::NoChecks).should eq Github::ChecksState::NoChecks
    end
  end

  describe "#blocks_mention?" do
    it "blocks while checks are failing or still running" do
      Github::ChecksState::Failure.blocks_mention?.should be_true
      Github::ChecksState::Pending.blocks_mention?.should be_true
    end

    it "does not block on success, no checks, or a failed lookup" do
      Github::ChecksState::Success.blocks_mention?.should be_false
      Github::ChecksState::NoChecks.blocks_mention?.should be_false
      Github::ChecksState::Unknown.blocks_mention?.should be_false
    end
  end
end

describe Github::CheckRuns do
  describe "#checks_state" do
    it "is success when every run completed without a blocking conclusion" do
      check_runs_from([
        {status: "completed", conclusion: "success"},
        {status: "completed", conclusion: "skipped"},
        {status: "completed", conclusion: "neutral"},
      ]).checks_state.should eq Github::ChecksState::Success
    end

    it "is failure when a completed run has a blocking conclusion" do
      check_runs_from([
        {status: "completed", conclusion: "success"},
        {status: "completed", conclusion: "failure"},
      ]).checks_state.should eq Github::ChecksState::Failure
    end

    it "is pending while a run has not completed" do
      check_runs_from([
        {status: "completed", conclusion: "success"},
        {status: "in_progress", conclusion: nil},
      ]).checks_state.should eq Github::ChecksState::Pending
    end

    it "is no-checks when the commit has no check run" do
      check_runs_from([] of NamedTuple(status: String, conclusion: String?)).checks_state.should eq Github::ChecksState::NoChecks
    end
  end
end

describe Github::CombinedStatus do
  describe "#checks_state" do
    it "maps the combined state" do
      combined_status_from("success", 2).checks_state.should eq Github::ChecksState::Success
      combined_status_from("failure", 2).checks_state.should eq Github::ChecksState::Failure
      combined_status_from("error", 2).checks_state.should eq Github::ChecksState::Failure
      combined_status_from("pending", 2).checks_state.should eq Github::ChecksState::Pending
    end

    it "is no-checks when the commit has no status, even though the api reports pending" do
      combined_status_from("pending", 0).checks_state.should eq Github::ChecksState::NoChecks
    end
  end
end

private def check_runs_from(runs)
  Github::CheckRuns.from_json({check_runs: runs}.to_json)
end

private def combined_status_from(state : String, total_count : Int32)
  Github::CombinedStatus.from_json({state: state, total_count: total_count}.to_json)
end

NOTIFICATIONS_FIXTURE = <<-JSON
  [
    {
      "reason": "mention",
      "subject": {
        "title": "Spurious failure",
        "url": "https://api.github.com/repos/octocat/Hello-World/issues/1",
        "latest_comment_url": "https://api.github.com/repos/octocat/Hello-World/issues/comments/1",
        "type": "Issue"
      },
      "updated_at": "2026-07-14T00:00:00Z",
      "repository": {
        "full_name": "octocat/Hello-World",
        "html_url": "https://github.com/octocat/Hello-World",
        "owner": {
          "login": "octocat",
          "avatar_url": "https://github.com/images/error/octocat.gif",
          "html_url": "https://github.com/octocat"
        }
      },
      "subscription_url": "https://api.github.com/notifications/threads/1/subscription"
    }
  ]
  JSON
