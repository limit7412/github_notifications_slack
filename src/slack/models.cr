require "json"
require "../notify/models"

module Slack
  class Attachment
    include JSON::Serializable

    getter fallback : String?
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
      @fallback = nil,
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

    # メンション時はチャンネル全体（@channel）に通知する。
    CHANNEL_MENTION = "<!channel>"

    def self.from_message(message : Notify::Message) : Attachment
      pretext =
        if message.mention?
          "#{CHANNEL_MENTION} #{message.pretext}"
        else
          message.pretext
        end

      Attachment.new(
        fallback: message.pretext,
        author_name: message.author_name,
        author_icon: message.author_icon,
        author_link: message.author_link,
        pretext: pretext,
        color: message.color,
        title: message.title,
        title_link: message.title_link,
        text: message.text,
        footer: message.footer,
        footer_icon: message.footer_icon,
      )
    end
  end

  class Post
    include JSON::Serializable

    getter attachments : Array(Attachment)

    def initialize(@attachments)
    end

    def self.build(messages : Array(Notify::Message)) : Post
      Post.new(messages.map { |message| Attachment.from_message(message) })
    end
  end
end
