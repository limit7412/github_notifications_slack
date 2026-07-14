require "../spec_helper"
require "../../src/github/repository"
require "../../src/github/usecase"

# HTTP を張らずに、あらかじめ用意した Comment を返すリポジトリ。
private class StubRepo < Github::NotificationRepository
  def initialize(@comment : Github::Comment)
    super("token")
  end

  def find_comment_by_url(url : String) : Github::Comment
    @comment
  end
end

private def notification(
  url = "https://api.github.com/repos/octocat/Hello-World/issues/42",
  reason = "review_requested",
  repo_html_url : String? = "https://github.com/octocat/Hello-World",
)
  Github::Notification.from_json({
    reason:     reason,
    subject:    {type: "Issue", title: "Spurious failure", url: url},
    repository: {full_name: "octocat/Hello-World", html_url: repo_html_url, owner: {login: "octocat"}},
    updated_at: "2026-07-14T00:00:00Z",
  }.to_json)
end

private def comment(body : String? = "body", html_url : String? = "https://example.com/c")
  Github::Comment.from_json({body: body, html_url: html_url, user: {login: "octocat"}}.to_json)
end

private def build(notify, comment)
  Github::Usecase.new(StubRepo.new(comment)).build_message(notify)
end

describe Github::Usecase do
  describe "#build_message" do
    it "reflects the reason in the pretext" do
      build(notification(reason: "review_requested"), comment).pretext.should eq "[Issue] レビューを依頼されました"
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
end
