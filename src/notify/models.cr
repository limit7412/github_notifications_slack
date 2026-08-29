module Notify
  # 送信先に依存しない中立な通知メッセージ。
  # Slack / Discord などのアダプタがそれぞれの形式へ変換する。
  class Message
    getter? mention : Bool
    # 重要度の高い（自分宛ての）通知か。メンション対象かどうかで投稿を区切り、
    # `@channel` 付きの投稿に自分宛て以外を混ぜないために使う（issue #120）。
    #
    # mention? とは別に持つ。mention? は CI が赤い PR でチャンネル全体を叩かない
    # ための抑止（issue #105）が掛かった後の値で、抑止されても通知の重要度自体は
    # 下がらない。両者を同じフラグにすると、CI が赤いレビュー依頼が通常の通知に
    # 混ざってしまう。
    getter? important : Bool
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
      @important = false,
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
