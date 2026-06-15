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

# 依存はコールドスタート時に一度だけ生成し、ウォームスタート間で使い回すことで
# HTTP::Client のコネクション（TCP/SSL）を再利用する。
github_repo = Github::NotificationRepository.new GITHUB_TOKEN
notify_uc = Notify::Usecase.new(
  github_repo,
  Github::Usecase.new(github_repo, SLACK_ID),
  Slack::PostRepository.new(WEBHOOK_URL),
)
error_uc = Error::Usecase.new(
  Slack::PostRepository.new(ALERT_WEBHOOK_URL),
  SLACK_ID,
  APP_ENV,
)

Serverless::Lambda.handler "github_notifications_slack" do |_|
  begin
    notify_uc.check_notifications
  rescue err
    error_uc.alert err
    raise err
  end
end
