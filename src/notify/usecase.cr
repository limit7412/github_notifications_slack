require "../github/models"
require "../github/repository"
require "../github/usecase"
require "../slack/models"
require "../slack/repository"

module Notify
  class Usecase
    def check_notifications
      githubRepo = Github::NotificationRepository.new ENV["GITHUB_TOKEN"]
      githubUC = Github::Usecase.new

      notices = githubRepo
        .find_notifications_unread
        .map do |item|
          message =
            if item.subject.update?
              "更新があったみたいです。確認してみましょう！"
            else
              "なにかあったみたいです。確認してみましょう！"
            end
          pretext = "[#{item.subject.type}] #{message}"

          githubUC.to_slack_attachment item, pretext, message
        end

      if notices.size != 0
        slackRepo = Slack::PostRepository.new ENV["WEBHOOK_URL"]
        slackRepo.send_attachments notices

        githubRepo.notification_to_read
      end

      {msg: "ok"}
    end
  end
end
