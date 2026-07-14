require "./models"
require "./repository"
require "../notify/models"

module Github
  class Usecase
    # コメント本文の掲載上限。全文はリンク先で読む前提で、通知が長文で流れるのを
    # 防ぐため組み立て側（Slack / Discord 共通）で切り詰める（issue #96）。
    BODY_LIMIT = 500

    def initialize(@repo : NotificationRepository)
    end

    def build_message(notify : Notification) : Notify::Message
      comment = @repo.find_comment_by_url notify.subject.comment_url
      Notify::Message.new(
        mention: notify.mention?,
        author_name: comment.user.login,
        author_icon: comment.user.avatar_url,
        author_link: comment.user.html_url,
        pretext: notify.pretext,
        color: notify.subject.color,
        title: notify.display_title,
        title_link: notify.link(comment),
        text: truncate_body(comment.body),
        footer: notify.repository.full_name || "github",
        footer_icon: notify.repository.owner.avatar_url,
      )
    end

    private def truncate_body(body : String?) : String?
      return nil unless text = body.try(&.presence)
      text.size > BODY_LIMIT ? "#{text[0, BODY_LIMIT]}…" : text
    end
  end
end
