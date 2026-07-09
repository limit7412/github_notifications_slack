require "./runtime/lambda"
require "./github/repository"
require "./github/usecase"
require "./notify/usecase"
require "./notify/poster"
require "./slack/repository"
require "./discord/repository"
require "./error/usecase"

# 必須の環境変数は起動時に解決し、欠如していればこの時点で失敗させる。
GITHUB_TOKEN      = ENV["GITHUB_TOKEN"]
WEBHOOK_URL       = ENV["WEBHOOK_URL"]
ALERT_WEBHOOK_URL = ENV["ALERT_WEBHOOK_URL"]
# メンション先 ID は Slack / Discord で体系が異なるため一般化する。
# 後方互換として未設定時は従来の SLACK_ID を使い、どちらも無ければ明示的に失敗させる。
MENTION_ID = ENV["MENTION_ID"]? || ENV["SLACK_ID"]? ||
             raise "Missing ENV key: \"MENTION_ID\" (fallback \"SLACK_ID\" も未設定)"
NOTIFY_MODE = ENV["NOTIFY_MODE"]? || "slack"
APP_ENV     = ENV["ENV"]

# NOTIFY_MODE に応じて送信先アダプタを生成する。
# 未設定時は既定の slack だが、想定外の値（typo 等）は起動時に例外にして
# 設定ミスに気づけるようにする（Slack 形式を Discord webhook へ誤送しない）。
def build_poster(url : String) : Notify::Poster
  case NOTIFY_MODE
  when "slack"
    Slack::PostRepository.new(url, MENTION_ID)
  when "discord"
    Discord::PostRepository.new(url, MENTION_ID)
  else
    raise %(Unknown NOTIFY_MODE: #{NOTIFY_MODE.inspect} (expected "slack" or "discord"))
  end
end

# 依存はコールドスタート時に一度だけ生成し、ウォームスタート間で使い回すことで
# HTTP::Client のコネクション（TCP/SSL）を再利用する。
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
