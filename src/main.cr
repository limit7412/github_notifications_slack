require "./runtime/lambda"
require "./github/repository"
require "./github/usecase"
require "./notify/usecase"
require "./notify/repository"
require "./slack/repository"
require "./discord/repository"
require "./error/usecase"

# 必須の環境変数は起動時に解決し、欠如していればこの時点で失敗させる。
GITHUB_TOKEN      = ENV["GITHUB_TOKEN"]
WEBHOOK_URL       = ENV["WEBHOOK_URL"]
ALERT_WEBHOOK_URL = ENV["ALERT_WEBHOOK_URL"]
NOTIFY_MODE       = ENV["NOTIFY_MODE"]? || "slack"
APP_ENV           = ENV["ENV"]

# NOTIFY_MODE に応じて送信先アダプタを生成する。
# 未設定時は既定の slack だが、想定外の値（typo 等）は起動時に例外にして
# 設定ミスに気づけるようにする（Slack 形式を Discord webhook へ誤送しない）。
def build_poster(url : String) : Notify::PostRepository
  case NOTIFY_MODE
  when "slack"
    Slack::PostRepository.new(url)
  when "discord"
    Discord::PostRepository.new(url)
  else
    raise %(Unknown NOTIFY_MODE: #{NOTIFY_MODE.inspect} (expected "slack" or "discord"))
  end
end

# 依存はコールドスタート時に一度だけ生成し、ウォームスタート間で使い回すことで
# HTTP::Client のコネクション（TCP/SSL）を再利用する。
# ただし GitHub への接続は、古いレプリカへの固定で未読通知が長時間取得できなく
# なる事象があったため、実行ごとに張り直す（issue #102 /
# Github::NotificationRepository#find_notifications_unread 参照）。
github_repo = Github::NotificationRepository.new GITHUB_TOKEN
notify_uc = Notify::Usecase.new(
  github_repo,
  Github::Usecase.new(github_repo),
  build_poster(WEBHOOK_URL),
)
error_uc = Error::Usecase.new(
  build_poster(ALERT_WEBHOOK_URL),
  APP_ENV,
)

Serverless::Lambda.handler "github_notifications_slack" do |_|
  begin
    notify_uc.check_notifications
  rescue error
    error_uc.alert error
    raise error
  end
end
