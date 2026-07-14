require "json"
require "../notify/models"

module Discord
  # Discord の制約値。
  EMBEDS_PER_MESSAGE =   10 # 1 メッセージあたり embeds 最大 10 件
  TOTAL_CHARS_LIMIT  = 6000 # 1 メッセージ内 embeds 合計文字数の上限
  CONTENT_LIMIT      = 2000 # content 最大 2000 文字
  DESCRIPTION_LIMIT  = 4096 # embed description 最大 4096 文字
  TITLE_LIMIT        =  256 # embed title 最大 256 文字

  # メンション時はチャンネル全体（@everyone）に通知する。
  EVERYONE_MENTION = "@everyone"

  def self.truncate(text : String, limit : Int32) : String
    text.size > limit ? text[0, limit] : text
  end

  class Post
    include JSON::Serializable

    getter content : String?
    getter embeds : Array(Embed)

    def initialize(@embeds, @content = nil)
    end

    # 中立メッセージ列を Discord の投稿単位へ分割して組み立てる。
    # embeds は最大 10 件、かつ 1 メッセージ内 embeds の合計文字数が 6000 を
    # 超えないよう詰め込む（超過すると Discord が 400 を返すため）。
    def self.build(messages : Array(Notify::Message)) : Array(Post)
      posts = [] of Post
      chunk = [] of Embed
      pretexts = [] of String
      chunk_chars = 0
      mention = false

      flush = -> do
        return if chunk.empty?
        posts << Post.new(chunk, build_content(pretexts, mention))
        chunk = [] of Embed
        pretexts = [] of String
        chunk_chars = 0
        mention = false
      end

      messages.each do |message|
        embed = Embed.from_message(message)
        size = embed.char_count
        if !chunk.empty? && (chunk.size >= EMBEDS_PER_MESSAGE || chunk_chars + size > TOTAL_CHARS_LIMIT)
          flush.call
        end
        chunk << embed
        chunk_chars += size
        if pretext = message.pretext.try(&.presence)
          pretexts << pretext
        end
        mention = true if message.mention?
      end
      flush.call

      posts
    end

    # botのセリフ（pretext）を content に出力する。embed には pretext 相当の欄が
    # 無いため、Slack と同様に「botの発言行」として embed の外（content）へ出す
    # （issue #95）。メンションは embed 内では機能しないため content 先頭に
    # @everyone を添える。チャンク内で重複するセリフは uniq でまとめ、content は
    # 2000 文字上限があるため truncate する。
    private def self.build_content(pretexts : Array(String), mention : Bool) : String?
      lines = [] of String
      lines << EVERYONE_MENTION if mention
      lines.concat pretexts.uniq
      return nil if lines.empty?
      Discord.truncate(lines.join("\n"), CONTENT_LIMIT)
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

    # Discord の 6000 文字制限が対象とするフィールド（title / description /
    # author.name / footer.text）の合計文字数。
    def char_count : Int32
      [title, description, author.try(&.name), footer.try(&.text)]
        .compact
        .sum(&.size)
    end

    def self.from_message(message : Notify::Message) : Embed
      # pretext（botのセリフ）は Post の content 側に出すため、description には
      # 含めずコメント本文のみとする（二重表示を避ける / issue #95）。
      description = message.text.try(&.presence)

      Embed.new(
        title: message.title.try { |value| Discord.truncate(value, TITLE_LIMIT) },
        # 空文字の URL は Discord に 400 で弾かれるため nil にする。
        url: message.title_link.presence,
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
      # 空文字の URL は Discord に 400 で弾かれるため nil にする。
      Author.new(message.author_name, message.author_link.presence, message.author_icon.presence)
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
      # 空文字の icon_url は Discord に 400 で弾かれるため nil にする
      # （アラートは footer_icon: "" で来るため特に重要）。
      Footer.new(message.footer, message.footer_icon.presence)
    end
  end
end
