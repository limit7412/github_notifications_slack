require "json"

class GithubNotifications
  include JSON::Serializable

  property subject : GithubSubject
  property reason : String
  property repository : GithubRepository
  property subscription_url : String?

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

  private def decision_type
    pretext = "[#{type}] 更新があったみたいです。 確認してみましょう！"
    color = "#D8D8D8"

    case type
    when "PullRequest"
      color = "#F6CEE3"
    when "Issue"
      color = "#A9D0F5"
    when "Commit"
      color = "#f5d7a9"
    else
      pretext = "[#{type}] なにかあったみたいです。 確認してみましょう！"
    end

    {
      pretext: pretext,
      color:   color,
    }
  end

  def pretext : String
    decision_type[:pretext]
  end

  def color : String
    decision_type[:color]
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
