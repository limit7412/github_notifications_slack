require "json"

module Github
  # PR の CI などの自動チェックの集計状態（issue #105）。
  # check runs（GitHub Actions 等）と commit status の 2 系統をまとめて表す。
  enum ChecksState
    Success  # 全て完了し、ブロックする結果が無い
    Pending  # 未完了のチェックがある
    Failure  # 失敗したチェックがある
    NoChecks # チェックが 1 つも設定されていない
    Unknown  # 取得できなかった

    # 2 系統の結果を 1 つに畳む。厳しい方（Failure > Pending > Success >
    # NoChecks）を採る。Unknown は「情報が無い」だけなので、もう片方が
    # 取得できていればそちらの結果を活かす。
    def merge(other : ChecksState) : ChecksState
      return other if unknown?
      return self if other.unknown?
      return Failure if failure? || other.failure?
      return Pending if pending? || other.pending?
      return Success if success? || other.success?
      NoChecks
    end

    # メンションを抑止すべき状態か。
    # 成功、チェック未設定、取得失敗のいずれでもメンションする。取得できなかった場合に
    # 抑止すると通知の見逃しにつながるため、安全側（誤メンションを許容）に倒す。
    def blocks_mention? : Bool
      failure? || pending?
    end
  end

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

    # reason（なぜ自分に通知されたか）ごとの表示文言。以前は update? に応じた
    # 「更新があったみたいです」の一辺倒で通知理由が伝わらなかったため、reason を
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
    # ではないため、一度レビュー依頼やアサインを受けた PR / Issue は、以降のコメントや
    # 更新もすべて同じ reason で届く。REASON_MESSAGES だけだと常に「レビューを依頼
    # されました」「アサインされました」になり通知理由が実態と合わないので、
    # 初回ではないと判断できる通知は文言を差し替える（issue #104）。
    #
    # 何が起きたか（コメントか push か状態変更か）は通知 payload から判別できない
    # ため、文言はコメントに限定せず「動きがありました」に留める。
    # ここに reason を足せば他の reason にも同じ切り替えを適用できる。
    #
    # 切り替えの判定は Subject#commented? だけでは足りず、本文取得で得た subject
    # 本体のコメント数も併用する（issue #116。詳細は followup? のコメント）。
    FOLLOWUP_MESSAGES = {
      "review_requested" => "レビュー依頼中の PR に動きがありました",
      "assign"           => "担当している PR/Issue に動きがありました",
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

    # reason に対応する文言。detail には本文取得で得た subject 本体（PR / Issue）を
    # 渡す。コメントの有無の判定に使うだけなので、渡さなければ従来どおり
    # Subject#commented? のみで判定する。
    def reason_message(detail : Comment? = nil) : String
      if followup?(detail)
        followup = FOLLOWUP_MESSAGES[reason]?
        return followup if followup
      end

      REASON_MESSAGES[reason]? || GENERIC_MESSAGE
    end

    # 「初回ではない＝その後の動き」とみなせるか。
    #
    # Subject#commented?（latest_comment_url が subject.url と異なる）だけでは
    # 取りこぼす。latest_comment_url は通知を発生させたイベント側を反映することが
    # あり、コメント済みのスレッドでも push やレビュー、アサイン変更が起点の通知では
    # subject.url に戻る。またレビューコメントは latest_comment_url に現れない
    # ことがあるため、レビュー上でだけ議論されている PR は常に初回扱いになる。
    # 結果、コメントの付いた PR でも「アサインされました」のままになる（issue #116）。
    #
    # そこで本文表示のためにどのみち取得している subject 本体のレスポンスを使う。
    # Subject#commented? が false のとき comment_url は PR / Issue 自体を指し、
    # そのレスポンスにはコメント数（PR は会話とレビューの 2 種）が含まれるので、
    # 追加の API 呼び出し無しでスレッドにコメントがあるかを判定できる。
    #
    # 逆に Subject#commented? が true のときは取得先が実コメントでコメント数を
    # 持たないが、その場合は先に true が確定するので影響しない。
    private def followup?(detail : Comment?) : Bool
      return true if subject.commented?
      return false unless detail

      detail.commented?
    end

    # CI などの自動チェックの状態でメンションを抑止する対象か（issue #105）。
    # レビューできる状態になっていない PR で `@channel` / `@everyone` を撃たない
    # ことが目的なので、PR の通知はすべて対象にする。
    #
    # 当初は mention / team_mention を「人が明示的に呼んだ」ものとして対象外に
    # していたが、reason は購読理由であってイベント種別ではないため（FOLLOWUP_MESSAGES
    # のコメント参照）、一度メンションされた PR はその後の push やコメントでも
    # reason=mention のまま届く。これを対象外にすると、最も関与している PR でこそ
    # チェックが赤いままチャンネル全体を叩いてしまい本末転倒なので、reason による
    # 例外は設けない（PR #107 レビュー指摘）。
    #
    # 実際に今回の更新がメンションだったかは通知 payload からは判別できない。
    # メンションされた通知自体は従来どおり届き、`@channel` が付かなくなるだけ。
    def checks_gated? : Bool
      subject.type == Subject::Type::PULL_REQUEST
    end

    # 通知の pretext（bot のセリフ）。`[<type>] <reason 文言>` 形式。
    # detail は reason_message にそのまま渡す（issue #116）。
    def pretext(detail : Comment? = nil) : String
      "[#{subject.type}] #{reason_message(detail)}"
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

    # スレッドにコメントが 1 件以上付いているか。latest_comment_url はスレッドの
    # 最新コメントの URL だが、コメントがまだ無いスレッドでは subject.url と同じ
    # 値が入る。よって url と異なる値のときだけコメントありと判断できる。
    #
    # あくまで「コメントが存在するか」であって「今回の通知の起点がコメントか」では
    # ない点に注意。通知 payload にイベント種別が無く、追加の API 呼び出し無しでは
    # 区別できないので、これを「初回ではない＝その後の動き」の目安として使い、
    # 文言側はコメントに限定しない表現にしている（issue #104 / PR #106 レビュー指摘）。
    #
    # ただし真になるのは片道で、これが偽でもコメントが無いとは限らない。
    # latest_comment_url は通知を発生させたイベント側を反映することがあり、
    # コメント済みでも push などが起点の通知では subject.url に戻る。よって
    # 「コメントが無い」側の確定には使えず、Notification#followup? では subject
    # 本体のコメント数と併用する（issue #116）。
    def commented? : Bool
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

  # 通知本文の取得結果。コメントが無いスレッドでは subject 本体（PR / Issue）を
  # 取得するため、コメントと subject 本体の両方をこの 1 クラスで受ける。
  class Comment
    include JSON::Serializable

    getter user : User
    getter html_url : String?
    getter body : String?
    # スレッドのコメント数。subject 本体を取得したときだけ入り、コメント
    # オブジェクトのレスポンスには無いため nilable（issue #116）。
    # PR は会話タブ（comments）とレビュー（review_comments）で別カウントになる。
    getter comments : Int32?
    getter review_comments : Int32?

    def initialize(@body)
      @user = User.new
    end

    # スレッドにコメントが 1 件以上付いているか（issue #116）。
    # 件数が取れない場合（コメントオブジェクト、本文取得失敗、本文なし通知）は
    # 判断材料が無いので false を返し、呼び出し側で初回向け文言に倒す。
    def commented? : Bool
      total = (comments || 0) + (review_comments || 0)
      total.positive?
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

  # チェック状態の判定に使う PR 情報。head の SHA だけ参照する（issue #105）。
  class PullRequest
    include JSON::Serializable

    getter head : Head

    class Head
      include JSON::Serializable

      getter sha : String
    end
  end

  # GET /repos/:owner/:repo/commits/:ref/check-runs のレスポンス（issue #105）。
  class CheckRuns
    include JSON::Serializable

    # ブロックしない conclusion。neutral / skipped は「実行された上で
    # 通していい」結果なので成功側に含める。
    PASSING_CONCLUSIONS = {
      "success",
      "neutral",
      "skipped",
    }

    getter check_runs : Array(CheckRun) = [] of CheckRun

    def checks_state : ChecksState
      return ChecksState::NoChecks if check_runs.empty?
      return ChecksState::Pending unless check_runs.all?(&.completed?)

      check_runs.all?(&.passing?) ? ChecksState::Success : ChecksState::Failure
    end

    class CheckRun
      include JSON::Serializable

      getter status : String = ""
      getter conclusion : String?

      def completed? : Bool
        status == "completed"
      end

      def passing? : Bool
        conclusion.in?(PASSING_CONCLUSIONS)
      end
    end
  end

  # GET /repos/:owner/:repo/commits/:ref/status のレスポンス（issue #105）。
  # check runs とは別系統の commit status（外部 CI 等）を表す。
  class CombinedStatus
    include JSON::Serializable

    getter state : String = ""
    getter total_count : Int32 = 0

    def checks_state : ChecksState
      # status が 1 件も無いと state は "pending" で返るため、件数で先に弾く。
      return ChecksState::NoChecks if total_count.zero?

      case state
      when "success"
        ChecksState::Success
      when "failure", "error"
        ChecksState::Failure
      else
        ChecksState::Pending
      end
    end
  end

  class Error
    include JSON::Serializable

    getter message : String
    getter documentation_url : String?
  end
end
