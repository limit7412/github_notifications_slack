require "../spec_helper"
require "../../src/github/repository"
require "../../src/github/usecase"

# HTTP を張らずに、あらかじめ用意した Comment とチェック状態を返すリポジトリ。
private class StubRepo < Github::NotificationRepository
  getter checks_calls = 0

  def initialize(@comment : Github::Comment, @checks_state : Github::ChecksState = Github::ChecksState::NoChecks)
    super("token")
  end

  def find_comment_by_url(url : String) : Github::Comment
    @comment
  end

  def find_checks_state(notify : Github::Notification) : Github::ChecksState
    @checks_calls += 1
    @checks_state
  end
end

private def notification(
  url = "https://api.github.com/repos/octocat/Hello-World/issues/42",
  reason = "review_requested",
  repo_html_url : String? = "https://github.com/octocat/Hello-World",
  type = "Issue",
  latest_comment_url = "",
)
  Github::Notification.from_json({
    reason:     reason,
    subject:    {type: type, title: "Spurious failure", url: url, latest_comment_url: latest_comment_url},
    repository: {full_name: "octocat/Hello-World", html_url: repo_html_url, owner: {login: "octocat"}},
    updated_at: "2026-07-14T00:00:00Z",
  }.to_json)
end

private def comment(body : String? = "body", html_url : String? = "https://example.com/c")
  Github::Comment.from_json({body: body, html_url: html_url, user: {login: "octocat"}}.to_json)
end

# コメントが無いスレッドで本文取得先になる subject 本体（PR / Issue）のレスポンス。
# 件数を省くとコメントオブジェクトと同じ形になる（issue #116）。
private def subject_detail(comments : Int32? = nil, review_comments : Int32? = nil)
  Github::Comment.from_json({
    body:            "body",
    html_url:        "https://example.com/c",
    user:            {login: "octocat"},
    comments:        comments,
    review_comments: review_comments,
  }.to_json)
end

private def build(notify, comment)
  Github::Usecase.new(StubRepo.new(comment)).build_message(notify)
end

describe Github::Usecase do
  describe "#build_message" do
    it "reflects the reason in the pretext" do
      build(notification(reason: "review_requested"), comment).pretext.should eq "[Issue] レビューを依頼されました"
    end

    it "reflects the follow-up wording for a commented review-requested thread in the pretext" do
      notify = notification(
        reason: "review_requested",
        latest_comment_url: "https://api.github.com/repos/octocat/Hello-World/issues/comments/1",
      )
      build(notify, comment).pretext.should eq "[Issue] レビュー依頼中の PR に動きがありました"
    end

    # latest_comment_url からはコメントの有無が分からない通知でも、本文取得で
    # 得た subject 本体のコメント数で文言を切り替える（issue #116）。
    it "reflects the follow-up wording when the fetched pull request has comments" do
      message = build(pull_request(reason: "assign"), subject_detail(comments: 1, review_comments: 0))
      message.pretext.should eq "[PullRequest] 担当している PR/Issue に動きがありました"
    end

    it "keeps the initial wording when the fetched pull request has no comment" do
      message = build(pull_request(reason: "assign"), subject_detail(comments: 0, review_comments: 0))
      message.pretext.should eq "[PullRequest] アサインされました"
    end

    it "formats the title as owner/repo#number title" do
      build(notification, comment).title.should eq "octocat/Hello-World#42 Spurious failure"
    end

    it "uses the comment html_url as the title link" do
      build(notification, comment(html_url: "https://example.com/c")).title_link.should eq "https://example.com/c"
    end

    it "falls back to the repository html_url when the comment has no link" do
      message = build(notification(repo_html_url: "https://github.com/octocat/Hello-World"), comment(html_url: nil))
      message.title_link.should eq "https://github.com/octocat/Hello-World"
    end

    it "truncates a long comment body to the limit with an ellipsis" do
      message = build(notification, comment(body: "a" * 600))
      message.text.as(String).size.should eq Github::Usecase::BODY_LIMIT + 1
      message.text.as(String).should end_with "…"
    end

    it "keeps a short comment body unchanged" do
      build(notification, comment(body: "short")).text.should eq "short"
    end

    it "leaves text nil when there is no comment body" do
      build(notification, comment(body: nil)).text.should be_nil
    end
  end

  describe "#build_message mention" do
    it "mentions on a pull request whose checks all succeeded" do
      message = build_with_checks(pull_request, Github::ChecksState::Success)
      message.mention?.should be_true
    end

    it "does not mention while a pull request has failing checks" do
      build_with_checks(pull_request, Github::ChecksState::Failure).mention?.should be_false
    end

    it "does not mention while a pull request still has running checks" do
      build_with_checks(pull_request, Github::ChecksState::Pending).mention?.should be_false
    end

    it "mentions when the pull request has no checks configured" do
      build_with_checks(pull_request, Github::ChecksState::NoChecks).mention?.should be_true
    end

    it "mentions when the checks state could not be fetched" do
      build_with_checks(pull_request, Github::ChecksState::Unknown).mention?.should be_true
    end

    it "does not mention on a failing pull request even for a mention reason" do
      # reason=mention は一度メンションされた PR に永続するため、その後の
      # push やコメントでも維持される。例外にすると赤い PR でチャンネル全体を
      # 叩いてしまうので、mention 系もチェック状態で制御する。
      notify = pull_request(reason: "mention")
      build_with_checks(notify, Github::ChecksState::Failure).mention?.should be_false
    end

    it "mentions on a passing pull request for a mention reason" do
      notify = pull_request(reason: "mention")
      build_with_checks(notify, Github::ChecksState::Success).mention?.should be_true
    end

    it "keeps non-mention reasons unmentioned regardless of the checks state" do
      notify = pull_request(reason: "subscribed")
      build_with_checks(notify, Github::ChecksState::Success).mention?.should be_false
    end

    it "does not look up checks for non pull request subjects" do
      repo = StubRepo.new(comment, Github::ChecksState::Failure)
      message = Github::Usecase.new(repo).build_message(notification(reason: "review_requested"))

      message.mention?.should be_true
      repo.checks_calls.should eq 0
    end

    it "does not look up checks for reasons that never mention" do
      repo = StubRepo.new(comment, Github::ChecksState::Failure)
      message = Github::Usecase.new(repo).build_message(pull_request(reason: "subscribed"))

      message.mention?.should be_false
      repo.checks_calls.should eq 0
    end
  end
end

private def pull_request(reason = "review_requested")
  notification(
    url: "https://api.github.com/repos/octocat/Hello-World/pulls/42",
    reason: reason,
    type: "PullRequest",
  )
end

private def build_with_checks(notify, checks_state)
  Github::Usecase.new(StubRepo.new(comment, checks_state)).build_message(notify)
end
