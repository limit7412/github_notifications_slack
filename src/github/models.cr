require "json"

module Github
  class Notification
    include JSON::Serializable

    MENTION_REASONS = {
      "assign",
      "author",
      "comment",
      "invitation",
      "mention",
      "team_mention",
      "review_requested",
      # "ci_activity",
    }

    getter subject : Subject
    getter reason : String
    getter repository : Repository
    getter subscription_url : String?

    def mention? : Bool
      reason.in?(MENTION_REASONS)
    end
  end

  class Subject
    include JSON::Serializable

    getter type : String
    getter title : String?
    getter url : String = ""
    getter latest_comment_url : String = ""

    module Type
      PULL_REQUEST = "PullRequest"
      ISSUE        = "Issue"
      COMMIT       = "Commit"
      DISCUSSION   = "Discussion"
    end

    UPDATE_TYPES = {
      Type::PULL_REQUEST,
      Type::ISSUE,
      Type::COMMIT,
      Type::DISCUSSION,
    }

    def update? : Bool
      type.in?(UPDATE_TYPES)
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
      latest_comment_url.presence || url
    end
  end

  class Repository
    include JSON::Serializable

    getter full_name : String?
    getter html_url : String?
    getter owner : User
  end

  class Comment
    include JSON::Serializable

    getter user : User
    getter html_url : String?
    getter body : String?

    def initialize(@body)
      @user = User.new
    end
  end

  class User
    include JSON::Serializable

    getter login : String?
    getter avatar_url : String?
    getter html_url : String?

    def initialize
    end
  end

  class Error
    include JSON::Serializable

    getter message : String
    getter documentation_url : String?
  end
end
