require "./models"
require "./repository"
require "../notify/models"

module Github
  class Usecase
    def initialize(@repo : NotificationRepository)
    end

    def build_message(notify : Notification, pretext : String) : Notify::Message
      comment = @repo.find_comment_by_url notify.subject.comment_url
      Notify::Message.new(
        mention: notify.mention?,
        author_name: comment.user.login,
        author_icon: comment.user.avatar_url,
        author_link: comment.user.html_url,
        pretext: pretext,
        color: notify.subject.color,
        title: notify.subject.title,
        title_link: comment.html_url,
        text: comment.body,
        footer: notify.repository.full_name || "github",
        footer_icon: notify.repository.owner.avatar_url,
      )
    end
  end
end
