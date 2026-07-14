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

    def comment_url : String
      latest_comment_url.presence || url
    end

    # subject.url 末尾の PR / Issue / Discussion 番号。Commit（末尾が SHA）や
    # URL が無い場合など、数値でなければ nil を返す（issue #96）。
    def number : String?
      segment = url.split('/').last?
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
