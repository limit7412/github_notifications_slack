require "./repository/slack.cr"
require "./repository/github.cr"

class Usecase
  def initialize
  end

  def check_notifications
    github = Github.new ENV["GITHUB_USER_NAME"], ENV["GITHUB_TOKEN"]

    notices = github.get_notifications
    puts notices
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
