require "json"

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
  end

  class Post
    include JSON::Serializable

    getter attachments : Array(Attachment)

    def initialize(@attachments)
    end
  end
end
