require "./repository/slack.cr"
require "./repository/github.cr"
require "./models"

class Usecase
  def initialize
  end

  def check_notifications
    github = Github.new ENV["GITHUB_USER_NAME"], ENV["GITHUB_TOKEN"]

    notices = github.get_notifications

    notices.each do |line|
      type = decision_type line.subject.type
      mention = decision_reason line.reason
      comment = github.get_comment line.subject

      slack = Slack.new type[:webhook]

      post = {
        fallback:    type[:subject],
        author_name: comment.user.login,
        author_icon: comment.user.avatar_url,
        author_link: comment.user.html_url,
        pretext:     "#{mention}#{type[:subject]}",
        color:       type[:color],
        title:       line.subject.title,
        title_link:  comment.html_url,
        text:        comment.body,
        footer:      !line.repository.full_name.nil? ? line.repository.full_name : "github",
        footer_icon: line.repository.owner.avatar_url,
      }

      slack.send_post post
    end

    if notices.size != 0
      github.notification_to_read
    end

    {msg: "ok"}
  end

  def error(err)
    slack = Slack.new ENV["ALERT_WEBHOOK_URL"]

    message = "エラーみたい…確認してみよっか"
    post = {
      fallback: message,
      pretext:  "<@#{ENV["SLACK_ID"]}> #{message}",
      title:    err.message,
      text:     err.backtrace.join('\n'),
      color:    "#EB4646",
      footer:   "github_notifications_slack by #{ENV["MYNAME"]? ? ENV["MYNAME"] : "unknown"}",
    }

    slack.send_post post

    {msg: "ng"}
  end

  private def decision_type(type : String)
    case type
    when "PullRequest"
      {
        subject: "プルリクエストみたいです！ 一緒にレビューがんばりましょう！",
        webhook: ENV["PULL_REQUEST_WEBHOOK_URL"],
        color:   "#F6CEE3",
      }
    when "Issue"
      {
        subject: "イシューみたい 確認してみよっか",
        webhook: ENV["ISSUE_WEBHOOK_URL"],
        color:   "#A9D0F5",
      }
    else
      {
        subject: "なにかあったみたい #{type}だって",
        webhook: ENV["ISSUE_WEBHOOK_URL"],
        color:   "#D8D8D8",
      }
    end
  end

  private def decision_reason(reason : String) : String
    [
      "assign",
      "author",
      "comment",
      "invitation",
      "mention",
      "team_mention",
    ].includes?(reason) ? "<@#{ENV["SLACK_ID"]}> " : ""
  end
end
