module Notify
  # 送信先に依存しない中立な通知メッセージ。
  # Slack / Discord などのアダプタがそれぞれの形式へ変換する。
  class Message
    getter? mention : Bool
    getter author_name : String?
    getter author_icon : String?
    getter author_link : String?
    getter pretext : String?
    getter color : String?
    getter title : String?
    getter title_link : String?
    getter text : String?
    getter footer : String?
    getter footer_icon : String?

    def initialize(
      @mention = false,
      @author_name = nil,
      @author_icon = nil,
      @author_link = nil,
      @pretext = nil,
      @color = nil,
      @title = nil,
      @title_link = nil,
      @text = nil,
      @footer = nil,
      @footer_icon = nil,
    )
    end
  end
end
