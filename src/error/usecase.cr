require "../slack/models"
require "../slack/repository"

module Error
  class Usecase
    def initialize(@slack_repo : Slack::PostRepository, @slack_id : String, @env : String)
    end

    def alert(err)
      message = "エラーみたい…確認してみよっか"
      attachment = Slack::Attachment.new(
        fallback: message,
        pretext: "<@#{@slack_id}> #{message}",
        color: "#EB4646",
        title: err.message,
        text: err.backtrace?.try(&.join('\n')),
        footer: "github_notifications_slack (#{@env})",
        footer_icon: "",
      )
      @slack_repo.send_attachment attachment

      {msg: "ng"}
    end
  end
end
