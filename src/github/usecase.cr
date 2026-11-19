require "./models"
require "./repository"
require "../notify/models"

module Github
  class Usecase
    # コメント本文の掲載上限。全文はリンク先で読む前提で、通知が長文で流れるのを
    # 防ぐため組み立て側（Slack / Discord 共通）で切り詰める（issue #96）。
    BODY_LIMIT = 500

    # exclude_labels はメンションの対象から外すラベル名（parse_labels で正規化した集合）。
    def initialize(@repo : NotificationRepository, @exclude_labels : Set(String) = Set(String).new)
    end

    # カンマ区切りのラベル名（環境変数 EXCLUDE_LABELS）を集合にする。
    # GitHub のラベル名は大文字小文字を区別しないため、比較用に小文字へ揃える。
    # 前後の空白と空要素（末尾のカンマなど）は設定の揺れとして読み捨てる。
    def self.parse_labels(raw : String?) : Set(String)
      return Set(String).new unless raw

      raw.split(',').map(&.strip.downcase).reject(&.empty?).to_set
    end

    def build_message(notify : Notification) : Notify::Message
      comment = @repo.find_comment_by_url notify.subject.comment_url
      addressed = addressed?(notify)
      Notify::Message.new(
        mention: addressed && checks_allow_mention?(notify),
        # 投稿の区切りには、CI によるメンション抑止を反映しない
        # （issue #120。理由は Notify::Message#important? のコメント）。
        important: addressed,
        author_name: comment.poster.login,
        author_icon: comment.poster.avatar_url,
        author_link: comment.poster.html_url,
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

    # 自分宛てとして扱う通知か。メンションと投稿の区切りの両方の前提になる。
    #
    # mention 系 reason であっても、除外ラベル（EXCLUDE_LABELS）の付いた PR / Issue は
    # 自分宛てとして扱わない。自動マージされる PR のように人が確認しなくてよい通知で
    # チャンネル全体を叩かないためである。通知そのものは通常の通知として届く。
    #
    # CI によるメンション抑止（checks_allow_mention?）と違い、こちらは投稿の区切りにも
    # 反映する。CI が赤い PR は確認が要る通知のままだが、除外ラベルの付いた通知は
    # 確認が要らないので、`@channel` の付く投稿に混ぜない。
    #
    # ラベルを調べるのは mention 系 reason の通知に限る。それ以外はもともと
    # メンションしないので、ラベルを取得しても結果が変わらない。除外ラベルが
    # 未設定のときも取得しない。
    private def addressed?(notify : Notification) : Bool
      return false unless notify.mention?
      return true if @exclude_labels.empty?

      !@repo.find_labels(notify).intersects?(@exclude_labels)
    end

    # CI などの自動チェックの状態から見て、メンション（`@channel` / `@everyone`）を
    # 付けてよいか。
    #
    # PR は自動チェックが失敗中でも実行中でもないことを条件にする。まだレビューできる
    # 状態ではない PR でチャンネル全体を叩かないため（issue #105）。通知そのものは
    # 抑止しない。
    private def checks_allow_mention?(notify : Notification) : Bool
      return true unless notify.checks_gated?

      !@repo.find_checks_state(notify).blocks_mention?
    end

    private def truncate_body(body : String?) : String?
      return unless text = body.try(&.presence)
      text.size > BODY_LIMIT ? "#{text[0, BODY_LIMIT]}…" : text
    end
  end
end
