require "./repository/slack.cr"
require "./repository/github.cr"

class Usecase
  def initialize
  end

  def check_notifications
    github = Github.new ENV["GITHUB_USER_NAME"], ENV["GITHUB_TOKEN"]

    notices = github.get_notifications

    notices.each do |line|
      type = decision_type(line["type"])
      is_mention = decision_reason(line["reason"])

      if line["latest_url"].nil?
        body = get_comment line["comment_url"]
      else
        body = get_comment line["latest_url"]
      end

      slack = Slack.new type["webhook"]

      slack.send_post

      {
        fallback:    notice[:subject],
        author_name: notice[:author_name],
        author_icon: notice[:author_icon],
        author_link: notice[:author_link],
        pretext:     "#{notice[:mention]}#{notice[:subject]}",
        color:       notice[:color],
        title:       notice[:title],
        title_link:  notice[:title_link],
        text:        notice[:body],
        footer:      notice[:footer],
        footer_icon: notice[:avatar],
      }
    end

    if notices.length == 0
      github.notification_to_read
    end
  end

  def error(err)
    slack = Slack.new ENV["WEBHOOK_URL_IZUMI"]

    slack.send_post(
      "エラーみたい…確認してみよっか",
      err.message,
      err.backtrace.join("\n"),
      "#EB4646",
      ENV["SLACK_ID"]
    )
  end

  private def decision_type(type)
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

  private def decision_reason(reason) : Boolian
    is_mention = false
    if reason == "assign" ||
       reason == "author" ||
       reason == "comment" ||
       reason == "invitation"
      is_mention = true
    end

    return is_mention
  end
end
