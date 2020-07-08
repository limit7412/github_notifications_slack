require "json"

class GithubNotifications
  JSON.mapping(
    subject: GithubSubject,
    reason: String,
    repository: GithubRepository,
    subscription_url: String?,
  )
end

class GithubSubject
  JSON.mapping(
    type: String,
    title: String?,
    url: {
      type:    String,
      nilable: false,
      default: "",
    },
    latest_comment_url: {
      type:    String,
      nilable: false,
      default: "",
    },
  )
end

class GithubRepository
  JSON.mapping(
    full_name: String?,
    html_url: String?,
    owner: GithubUser,
  )
end

class GithubComment
  JSON.mapping(
    user: GithubUser,
    html_url: String?,
    body: String?,
  )
end

class GithubUser
  JSON.mapping(
    login: String?,
    avatar_url: String?,
    html_url: String?,
  )
end
