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
      # CI 完了通知（CheckSuite）などは subject.url を本文取得に使わない
      subject_from("CheckSuite", url: "https://api.github.com/repos/o/r/check-suites/1").comment_url.should eq ""
    end

    it "still uses latest_comment_url even for non-body types" do
      subject_from("Commit", url: "u", latest_comment_url: "c").comment_url.should eq "c"
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
      # Release は末尾が数値 ID でも #番号 表示は誤解を招くため付けない
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
  end

  describe "#pretext" do
    it "prefixes the subject type before the reason message" do
      notification_from("mention").pretext.should eq "[Issue] メンションされました"
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
    it "is true for pull request notifications with a machine-driven reason" do
      notification_from("review_requested", type: "PullRequest").checks_gated?.should be_true
      notification_from("assign", type: "PullRequest").checks_gated?.should be_true
      notification_from("author", type: "PullRequest").checks_gated?.should be_true
    end

    it "is false when a human explicitly mentioned the user" do
      notification_from("mention", type: "PullRequest").checks_gated?.should be_false
      notification_from("team_mention", type: "PullRequest").checks_gated?.should be_false
    end

    it "is false for non pull request subjects" do
      notification_from("review_requested", type: "Issue").checks_gated?.should be_false
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

private def notification_from(reason : String, type = "Issue")
  Github::Notification.from_json({
    reason:     reason,
    subject:    {type: type, title: "title"},
    repository: {owner: {login: "octocat"}},
    updated_at: "2026-07-14T00:00:00Z",
  }.to_json)
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
