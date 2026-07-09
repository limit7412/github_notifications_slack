require "../github/repository"
require "../github/usecase"
require "./repository"

module Notify
  class Usecase
    def initialize(
      @github_repo : Github::NotificationRepository,
      @github_uc : Github::Usecase,
      @poster : Notify::PostRepository,
    )
    end

    def check_notifications
      notices = @github_repo
        .find_notifications_unread
        .map do |item|
          message =
            if item.subject.update?
              "更新があったみたいです。確認してみましょう！"
            else
              "なにかあったみたいです。確認してみましょう！"
            end
          pretext = "[#{item.subject.type}] #{message}"

          @github_uc.build_message item, pretext
        end

      unless notices.empty?
        @poster.send_messages notices
        @github_repo.notification_to_read
      end

      {msg: "ok"}
    end
  end
end
