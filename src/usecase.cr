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

        comment = github.get_comment item.subject.comment_url
        Slack::Attachment.new(
          fallback: pretext,
          author_name: comment.user.login,
          author_icon: comment.user.avatar_url,
          author_link: comment.user.html_url,
          pretext: "#{item.mention? ? "<@#{ENV["SLACK_ID"]}> " : ""}#{pretext}",
          color: item.subject.color,
          title: item.subject.title,
          title_link: comment.html_url,
          text: comment.body,
          footer: !item.repository.full_name.nil? ? item.repository.full_name : "github",
          footer_icon: item.repository.owner.avatar_url,
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
      fallback: message,
      pretext: "<@#{ENV["SLACK_ID"]}> #{message}",
      color: "#EB4646",
      title: err.message,
      text: err.backtrace.join('\n'),
      footer: "github_notifications_slack (#{ENV["ENV"]})",
      footer_icon: "",
    )
    slack.send_attachment attachment

    {msg: "ng"}
  end
end
