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
        mention: mention?(notify),
        # 投稿の区切りは reason だけで決め、CI によるメンション抑止は反映しない
        # （issue #120。理由は Notify::Message#important? のコメント）。
        important: notify.mention?,
        author_name: comment.user.login,
        author_icon: comment.user.avatar_url,
        author_link: comment.user.html_url,
        # コメントが無いスレッドでは comment は subject 本体（PR / Issue）になる。
        # その中のコメント数を文言の切り替え判定に使う（issue #116）。
        pretext: notify.pretext(comment),
        color: notify.subject.color,
        title: notify.display_title,
        title_link: notify.link(comment),
        text: truncate_body(comment.body),
        footer: notify.repository.full_name || "github",
        footer_icon: notify.repository.owner.avatar_url,
      )
    end

    # メンション（`@channel` / `@everyone`）を付けるか。
    #
    # mention 系 reason であることに加え、PR は CI などの自動チェックが失敗中でも
    # 実行中でもないことを条件にする。まだレビューできる状態ではない PR でチャンネル全体を
    # 叩かないため（issue #105）。通知そのものは抑止しない。
    private def mention?(notify : Notification) : Bool
      return false unless notify.mention?
      return true unless notify.checks_gated?

      !@repo.find_checks_state(notify).blocks_mention?
    end

    private def truncate_body(body : String?) : String?
      return unless text = body.try(&.presence)
      text.size > BODY_LIMIT ? "#{text[0, BODY_LIMIT]}…" : text
    end
  end
end
