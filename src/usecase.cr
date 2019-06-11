require "./repository/slack.cr"

class Usecase
  def initialize
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
end
