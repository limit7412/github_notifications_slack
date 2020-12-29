require "json"

class SlackAttachment
  include JSON::Serializable

  property fallback : String?
  property author_name : String?
  property author_icon : String?
  property author_link : String?
  property pretext : String?
  property color : String?
  property title : String?
  property title_link : String?
  property text : String?
  property footer : String?
  property footer_icon : String?

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
    @footer_icon = nil
  )
  end
end

class SlackPost
  include JSON::Serializable

  property attachments : Array(SlackAttachment)

  def initialize(@attachments)
  end
end
