require "json"

class GithubNotifications
  include JSON::Serializable

  property subject : GithubSubject
  property reason : String
  property repository : GithubRepository
  property subscription_url : String?
  property comment : GithubComment

  def mention? : Bool
    [
      "assign",
      "author",
      "comment",
      "invitation",
      "mention",
      "team_mention",
      "review_requested",
    ].includes?(reason)
  end
end

class GithubSubject
  include JSON::Serializable

  property type : String
  property title : String?

  @[JSON::Field(emit_null: false)]
  property url : String = ""

  @[JSON::Field(emit_null: false)]
  property latest_comment_url : String = ""

  module Type
    PullRequest = "PullRequest"
    Issue       = "Issue"
    Commit      = "Commit"
  end

  def update? : Bool
    [
      Type::PullRequest,
      Type::Issue,
      Type::Commit,
    ].includes?(type)
  end

  def color : String
    case type
    when Type::PullRequest
      "#F6CEE3"
    when Type::Issue
      "#A9D0F5"
    when Type::Commit
      "#f5d7a9"
    else
      "#D8D8D8"
    end
  end

  def comment_url : String
    if !latest_comment_url.blank?
      latest_comment_url
    else
      url
    end
  end
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
