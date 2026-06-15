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

    it "falls back to url when latest_comment_url is blank" do
      subject = subject_from("Issue", url: "u", latest_comment_url: "")
      subject.comment_url.should eq "u"
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

  it "parses a GitHub notifications API payload" do
    notifications = Array(Github::Notification).from_json(NOTIFICATIONS_FIXTURE)
    notifications.size.should eq 1

    notification = notifications.first
    notification.reason.should eq "mention"
    notification.subject.type.should eq "Issue"
    notification.subject.title.should eq "Spurious failure"
    notification.repository.full_name.should eq "octocat/Hello-World"
    notification.mention?.should be_true
  end
end

private def notification_from(reason : String)
  Github::Notification.from_json({
    reason:     reason,
    subject:    {type: "Issue", title: "title"},
    repository: {owner: {login: "octocat"}},
  }.to_json)
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
