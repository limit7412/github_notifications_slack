require "./runtime/lambda"
require "./github/repository"
require "./github/usecase"
require "./notify/usecase"
require "./slack/repository"
require "./error/usecase"

# 必須の環境変数は起動時に解決し、欠如していればこの時点で失敗させる。
GITHUB_TOKEN      = ENV["GITHUB_TOKEN"]
WEBHOOK_URL       = ENV["WEBHOOK_URL"]
ALERT_WEBHOOK_URL = ENV["ALERT_WEBHOOK_URL"]
SLACK_ID          = ENV["SLACK_ID"]
APP_ENV           = ENV["ENV"]

Serverless::Lambda.handler "github_notifications_slack" do |_|
  begin
    github_repo = Github::NotificationRepository.new GITHUB_TOKEN
    github_uc = Github::Usecase.new github_repo, SLACK_ID
    slack_repo = Slack::PostRepository.new WEBHOOK_URL

    Notify::Usecase.new(github_repo, github_uc, slack_repo).check_notifications
  rescue err
    alert_repo = Slack::PostRepository.new ALERT_WEBHOOK_URL
    Error::Usecase.new(alert_repo, SLACK_ID, APP_ENV).alert err
    raise err
  end
end
