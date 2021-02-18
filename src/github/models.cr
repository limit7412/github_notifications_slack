require "json"

module Github
  class Notifications
    include JSON::Serializable

    property subject : Subject
    property reason : String
    property repository : Repository
    property subscription_url : String?
    property comment : Comment

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

  class Subject
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

  class Repository
    include JSON::Serializable

    property full_name : String?
    property html_url : String?
    property owner : User
  end

  class Comment
    include JSON::Serializable

    property user : User
    property html_url : String?
    property body : String?
  end

  class User
    include JSON::Serializable

    property login : String?
    property avatar_url : String?
    property html_url : String?
  end
end
