require "./models"

module Notify
  # 通知の送信先を抽象化するインターフェース。
  # Slack::PostRepository / Discord::PostRepository が実装する。
  abstract class Poster
    abstract def send_messages(messages : Array(Message))

    def send_message(message : Message)
      send_messages [message]
    end
  end
end
