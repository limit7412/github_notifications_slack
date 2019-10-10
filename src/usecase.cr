require "./repository/slack.cr"
require "./repository/github.cr"

class Usecase
  def initialize
  end

  def check_notifications
    github = Github.new ENV["GITHUB_USER_NAME"], ENV["GITHUB_TOKEN"]

    notices = github.get_notifications

    notices.each do |line|
      type = decision_type line[:type]
      mention = decision_reason line[:reason]

      comment = github.get_comment !line["latest_url"].blank? ? line[:latest_url] : line[:comment_url]

      slack = Slack.new type[:webhook]

      post = {
        fallback:    type[:subject],
        author_name: comment[:name],
        author_icon: comment[:icon],
        author_link: comment[:author_link],
        pretext:     "#{mention}#{type[:subject]}",
        color:       type[:color],
        title:       line[:title],
        title_link:  comment[:title_link],
        text:        comment[:body],
        footer:      !line[:repository_name].nil? ? line[:repository_name] : "github",
        footer_icon: line[:avatar],
      }

      slack.send_post post
    end

    if notices.size != 0
      github.notification_to_read
    end
  end

  def error(err)
    slack = Slack.new ENV["WEBHOOK_URL_IZUMI"]

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
  end

  private def decision_type(type : String)
    if type == "PullRequest"
      subject = "プルリクエストみたいです！ 一緒にレビューがんばりましょう！"
      webhook = ENV["WEBHOOK_URL_UDUKI"]
      color = "#F6CEE3"
    elsif type == "Issue"
      subject = "イシューみたい 確認してみよっか"
      webhook = ENV["WEBHOOK_URL_RIN"]
      color = "#A9D0F5"
    else
      subject = "なにかあったみたい #{type}だって"
      webhook = ENV["WEBHOOK_URL_RIN"]
      color = "#D8D8D8"
    end

    return {
      subject: subject,
      webhook: webhook,
      color:   color,
    }
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
