require "json"

module Github
  class Notifications
    include JSON::Serializable

    property subject : Subject
    property reason : String
    property repository : Repository
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
        "ci_activity",
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
      PULL_REQUEST = "PullRequest"
      ISSUE        = "Issue"
      COMMIT       = "Commit"
      DISCUSSION   = "Discussion"
    end

    def update? : Bool
      [
        Type::PULL_REQUEST,
        Type::ISSUE,
        Type::COMMIT,
        Type::DISCUSSION,
      ].includes?(type)
    end

    def color : String
      case type
      when Type::PULL_REQUEST
        "#F6CEE3"
      when Type::ISSUE
        "#A9D0F5"
      when Type::COMMIT
        "#f5d7a9"
      when Type::DISCUSSION
        "#7fffd4"
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

    def initialize(@body)
      @user = User.new
    end
  end

  class User
    include JSON::Serializable

    property login : String?
    property avatar_url : String?
    property html_url : String?

    def initialize
    end
  end

  class Error
    include JSON::Serializable

    property message : String
    property documentation_url : String?
  end
end
