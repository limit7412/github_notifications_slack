require "json"

module Github
  class Notification
    include JSON::Serializable

    MENTION_REASONS = {
      "assign",
      "author",
      "comment",
      "invitation",
      "mention",
      "team_mention",
      "review_requested",
      # "ci_activity",
    }

    # reason（なぜ自分に通知されたか）ごとの表示文言。update? による
    # 「更新があったみたいです」一辺倒だと通知理由が伝わらないため、reason を
    # 文面に反映する（issue #96）。GitHub 側の reason 追加に耐えるよう、
    # 未知の reason は reason_message で汎用文言にフォールバックする。
    REASON_MESSAGES = {
      "mention"          => "メンションされました",
      "team_mention"     => "メンションされました",
      "review_requested" => "レビューを依頼されました",
      "assign"           => "アサインされました",
      "author"           => "自分の PR/Issue に動きがありました",
      "comment"          => "コメントがつきました",
      "state_change"     => "状態が変わりました",
      "subscribed"       => "ウォッチ中のリポジトリで動きがありました",
      "ci_activity"      => "CI の実行結果が届きました",
      "invitation"       => "招待が届きました",
    }

    # 「一度きりの出来事」を指す reason 向けの、2 回目以降の文言。
    #
    # GitHub の reason は「そのスレッドを購読している理由」であってイベント種別
    # ではないため、一度レビュー依頼された PR は以降のコメントや更新もすべて
    # review_requested で届く。REASON_MESSAGES だけだと常に「レビューを依頼され
    # ました」になり通知理由が実態と合わないので、コメントが起点の通知に限り
    # 文言を差し替える（issue #104）。ここに reason を足せば他の reason にも
    # 同じ切り替えを適用できる。
    FOLLOWUP_MESSAGES = {
      "review_requested" => "レビュー依頼中の PR にコメントがつきました",
    }

    GENERIC_MESSAGE = "なにかあったみたいです。確認してみましょう！"

    getter subject : Subject
    getter reason : String
    getter repository : Repository
    getter subscription_url : String?
    # 分割送信時にチャンク単位で既読化するため、通知の更新時刻を保持する。
    # last_read_at に渡すことで送信済み分だけを既読化できる（issue #94）。
    getter updated_at : Time

    def mention? : Bool
      reason.in?(MENTION_REASONS)
    end

    def reason_message : String
      if subject.comment_triggered?
        followup = FOLLOWUP_MESSAGES[reason]?
        return followup if followup
      end

      REASON_MESSAGES[reason]? || GENERIC_MESSAGE
    end

    # 通知の pretext（botのセリフ）。`[<type>] <reason 文言>` 形式。
    def pretext : String
      "[#{subject.type}] #{reason_message}"
    end

    # 一目で対象が分かるよう `owner/repo#番号 タイトル` 形式にする。
    # 番号が取れない（Commit など）場合はタイトルのみ、リポジトリ名が無ければ
    # 番号のみにフォールバックする（issue #96）。
    def display_title : String?
      title = subject.title
      number = subject.number
      return title unless number

      prefix = repository.full_name.try { |name| "#{name}##{number}" } || "##{number}"
      title ? "#{prefix} #{title}" : prefix
    end

    # 対象へ飛べるリンク。コメントの html_url を優先し、無ければリポジトリの
    # html_url にフォールバックしてリンク無し通知を無くす（issue #96）。
    def link(comment : Comment) : String?
      comment.html_url.try(&.presence) || repository.html_url
    end
  end

  class Subject
    include JSON::Serializable

    getter type : String
    getter title : String?
    getter url : String = ""
    getter latest_comment_url : String = ""

    module Type
      PULL_REQUEST = "PullRequest"
      ISSUE        = "Issue"
      COMMIT       = "Commit"
      DISCUSSION   = "Discussion"
    end

    UPDATE_TYPES = {
      Type::PULL_REQUEST,
      Type::ISSUE,
      Type::COMMIT,
      Type::DISCUSSION,
    }

    # subject.url 末尾が GitHub 上の番号として意味を持つ type。Release / CheckSuite
    # のように末尾が数値 ID でも #番号 表示は誤解を招くため、これらに限定する。
    NUMBERED_TYPES = {
      Type::PULL_REQUEST,
      Type::ISSUE,
      Type::DISCUSSION,
    }

    # subject.url / latest_comment_url を取得すると本文（body）付きのオブジェクトが
    # 返る type。Commit / CheckSuite 等は body が無くコメントとして解釈できないため、
    # コメント URL が無ければ本文取得の対象にしない（CI 完了通知等に本文を付けない）。
    BODY_TYPES = {
      Type::PULL_REQUEST,
      Type::ISSUE,
    }

    def update? : Bool
      type.in?(UPDATE_TYPES)
    end

    def color : String
      case type
      when Type::PULL_REQUEST
        "#F6CEE3"
      when Type::ISSUE
        "#A9D0F5"
      when Type::COMMIT
        "#f5d7a9"
      when Type::DISCUSSION
        "#7fffd4"
      else
        "#D8D8D8"
      end
    end

    # 本文取得に使う URL。コメントがあればその URL、無ければ本文を持つ type に
    # 限り subject.url にフォールバックする。対象外（CI 等）は空文字を返し、
    # 呼び出し側で本文なし扱いにする（issue #96）。
    def comment_url : String
      return latest_comment_url if latest_comment_url.presence
      type.in?(BODY_TYPES) ? url : ""
    end

    # 通知の起点がコメントかどうか。latest_comment_url はスレッド最新コメントの
    # URL だが、コメントがまだ無いスレッドでは subject.url と同じ値が入る。
    # よって url と異なる値のときだけ「コメントが起点」と判断できる（issue #104）。
    #
    # 既にコメントの付いた PR に後からレビュー依頼された場合、起点は依頼でも
    # 直前のコメント URL が入るため誤判定する。通知 payload にイベント種別は
    # 無く、追加の API 呼び出し無しでは区別できないため許容する。
    def comment_triggered? : Bool
      return false unless comment = latest_comment_url.presence
      comment != url
    end

    # subject.url 末尾の PR / Issue / Discussion 番号。番号が意味を持つ type に
    # 限り、末尾セグメントが数値なら返す。Commit（末尾が SHA）や末尾スラッシュ、
    # URL が無い場合などは nil を返す（issue #96）。
    def number : String?
      return unless type.in?(NUMBERED_TYPES)
      segment = url.chomp('/').split('/').last?
      segment if segment && segment.matches?(/\A\d+\z/)
    end
  end

  class Repository
    include JSON::Serializable

    getter full_name : String?
    getter html_url : String?
    getter owner : User
  end

  class Comment
    include JSON::Serializable

    getter user : User
    getter html_url : String?
    getter body : String?

    def initialize(@body)
      @user = User.new
    end
  end

  class User
    include JSON::Serializable

    getter login : String?
    getter avatar_url : String?
    getter html_url : String?

    def initialize
    end
  end

  class Error
    include JSON::Serializable

    getter message : String
    getter documentation_url : String?
  end
end
