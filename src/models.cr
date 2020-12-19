require "json"

class GithubNotifications
  include JSON::Serializable

  property subject : GithubSubject
  property reason : String
  property repository : GithubRepository
  property subscription_url : String?
end

class GithubSubject
  include JSON::Serializable

  property type : String
  property title : String?

  @[JSON::Field(emit_null: false)]
  property url : String = ""

  @[JSON::Field(emit_null: false)]
  property latest_comment_url : String = ""
end

class GithubRepository
  include JSON::Serializable

  property full_name : String?
  property html_url : String?
  property owner : GithubUser
end

class GithubComment
  include JSON::Serializable

  property user : GithubUser
  property html_url : String?
  property body : String?
end

class GithubUser
  include JSON::Serializable

  property login : String?
  property avatar_url : String?
  property html_url : String?
end
