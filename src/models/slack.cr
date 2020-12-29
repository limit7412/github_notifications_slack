require "json"

class SlackAttachment
  include JSON::Serializable

  property fallback : String
  property author_name : String
  property author_icon : String
  property author_link : String
  property pretext : String
  property color : String
  property title : String
  property title_link : String
  property text : String
  property footer : String
  property footer_icon : String
end

class SlackPost
  include JSON::Serializable

  property attachments : Array(SlackAttachment)
end
