require "json"
require "../notify/models"

module Discord
  # Discord の制約値。
  EMBEDS_PER_MESSAGE =   10 # 1 メッセージあたり embeds 最大 10 件
  CONTENT_LIMIT      = 2000 # content 最大 2000 文字
  DESCRIPTION_LIMIT  = 4096 # embed description 最大 4096 文字
  TITLE_LIMIT        =  256 # embed title 最大 256 文字

  def self.truncate(text : String, limit : Int32) : String
    text.size > limit ? text[0, limit] : text
  end

  class Post
    include JSON::Serializable

    getter content : String?
    getter embeds : Array(Embed)

    def initialize(@embeds, @content = nil)
    end

    # 中立メッセージ列を Discord の投稿単位（embeds 最大 10 件）へ分割して組み立てる。
    def self.build(messages : Array(Notify::Message), mention_id : String) : Array(Post)
      messages.each_slice(EMBEDS_PER_MESSAGE).map do |chunk|
        # メンションは embed 内では機能しないため content に出力する。
        content =
          if chunk.any?(&.mention?)
            Discord.truncate("<@#{mention_id}>", CONTENT_LIMIT)
          end
        Post.new(chunk.map { |message| Embed.from_message(message) }, content)
      end.to_a
    end
  end

  class Embed
    include JSON::Serializable

    getter title : String?
    getter url : String?
    getter description : String?
    getter color : Int32?
    getter author : Author?
    getter footer : Footer?

    def initialize(
      @title = nil,
      @url = nil,
      @description = nil,
      @color = nil,
      @author = nil,
      @footer = nil,
    )
    end

    def self.from_message(message : Notify::Message) : Embed
      # Slack の pretext 相当の欄が embed には無いため text とまとめて description にする。
      description = [message.pretext, message.text]
        .compact
        .reject(&.empty?)
        .join("\n\n")
        .presence

      Embed.new(
        title: message.title.try { |value| Discord.truncate(value, TITLE_LIMIT) },
        url: message.title_link,
        description: description.try { |value| Discord.truncate(value, DESCRIPTION_LIMIT) },
        color: color_from_hex(message.color),
        author: Author.from_message(message),
        footer: Footer.from_message(message),
      )
    end

    # Slack で使う "#RRGGBB" 形式の色を Discord が要求する Int32 へ変換する。
    def self.color_from_hex(hex : String?) : Int32?
      return nil unless hex
      hex.lchop('#').to_i?(16)
    end
  end

  class Author
    include JSON::Serializable

    getter name : String?
    getter url : String?
    getter icon_url : String?

    def initialize(@name = nil, @url = nil, @icon_url = nil)
    end

    def self.from_message(message : Notify::Message) : Author?
      # Discord は author に name 必須のため、名前が無ければ author 自体を付けない。
      return nil unless message.author_name
      Author.new(message.author_name, message.author_link, message.author_icon)
    end
  end

  class Footer
    include JSON::Serializable

    getter text : String?
    getter icon_url : String?

    def initialize(@text = nil, @icon_url = nil)
    end

    def self.from_message(message : Notify::Message) : Footer?
      # Discord は footer に text 必須のため、footer が無ければ付けない。
      return nil unless message.footer
      Footer.new(message.footer, message.footer_icon)
    end
  end
end
