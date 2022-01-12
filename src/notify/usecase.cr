require "../github/models"
require "../github/repository"
require "../github/usecase"
require "../slack/models"
require "../slack/repository"

module Notify
  class Usecase
    def check_notifications
      github_repo = Github::NotificationRepository.new ENV["GITHUB_TOKEN"]
      github_uc = Github::Usecase.new

      notices = github_repo
        .find_notifications_unread
        .map do |item|
          message =
            if item.subject.update?
              "更新があったみたいです。確認してみましょう！"
            else
              "なにかあったみたいです。確認してみましょう！"
            end
          pretext = "[#{item.subject.type}] #{message}"

          github_uc.to_slack_attachment item, pretext, message
        end

      if notices.size != 0
        slack_repo = Slack::PostRepository.new ENV["WEBHOOK_URL"]
        slack_repo.send_attachments notices

        github_repo.notification_to_read
      end

      {msg: "ok"}
    end
  end
end
