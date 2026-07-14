require "./models"

module Notify
  # 通知の送信先を抽象化するインターフェース。
  # Slack::PostRepository / Discord::PostRepository が実装する。
  abstract class PostRepository
    # メッセージを送信先の投稿単位（チャンク）ごとに送る。
    # 1 チャンクの送信に成功するたび、そこまでに送信済みのメッセージ件数
    # （累計）を yield する。呼び出し側はこれを使って送信済み分だけを都度
    # 既読化でき、分割送信の途中失敗時に前半チャンクが重複投稿されるのを防ぐ
    # （issue #94）。Slack は全メッセージを 1 投稿で送るため atomic で、
    # 送信後に一度だけ全件を yield する。
    abstract def send_messages(messages : Array(Message), & : Int32 ->)

    def send_messages(messages : Array(Message))
      send_messages(messages) { }
    end

    def send_message(message : Message)
      send_messages [message]
    end
  end
end
