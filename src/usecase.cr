require "./github/models"
require "./github/repository"
require "./slack/models"
require "./slack/repository"

class Usecase
  def check_notifications
    github = Github::NotificationRepository.new ENV["GITHUB_TOKEN"]

    notices = github
      .get_notifications
      .map do |item|
        message =
          if item.subject.update?
            "更新があったみたいです。確認してみましょう！"
          else
            "なにかあったみたいです。確認してみましょう！"
          end
        pretext = "[#{item.subject.type}] #{message}"

        Slack::Attachment.new(
          fallback = pretext,
          author_name = item.comment.user.login,
          author_icon = item.comment.user.avatar_url,
          author_link = item.comment.user.html_url,
          pretext = "#{item.mention? ? "<@#{ENV["SLACK_ID"]}> " : ""}#{pretext}",
          color = item.subject.color,
          title = item.subject.title,
          title_link = item.comment.html_url,
          text = item.comment.body,
          footer = !item.repository.full_name.nil? ? item.repository.full_name : "github",
          footer_icon = item.repository.owner.avatar_url,
        )
      end

    if notices.size != 0
      slack = Slack::PostRepository.new ENV["WEBHOOK_URL"]
      slack.send_attachments notices

      github.notification_to_read
    end

    {msg: "ok"}
  end

  def error(err)
    slack = Slack::PostRepository.new ENV["ALERT_WEBHOOK_URL"]

    message = "エラーみたい…確認してみよっか"
    attachment = Slack::Attachment.new(
      fallback = message,
      pretext = "<@#{ENV["SLACK_ID"]}> #{message}",
      title = err.message,
      text = err.backtrace.join('\n'),
      color = "#EB4646",
      footer = "github_notifications_slack (#{ENV["ENV"]})",
    )
    slack.send_attachment attachment

    {msg: "ng"}
  end
end
