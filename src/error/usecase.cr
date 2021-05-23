require "../slack/models"
require "../slack/repository"

module Error
  class Usecase
    def alert(err)
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
end
