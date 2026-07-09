require "../notify/models"
require "../notify/repository"

module Error
  class Usecase
    def initialize(@poster : Notify::PostRepository, @env : String)
    end

    def alert(err)
      message = "エラーみたい…確認してみよっか"
      @poster.send_message Notify::Message.new(
        mention: true,
        pretext: message,
        color: "#EB4646",
        title: err.message,
        text: err.backtrace?.try(&.join('\n')),
        footer: "github_notifications_slack (#{@env})",
        footer_icon: "",
      )

      {msg: "ng"}
    end
  end
end
