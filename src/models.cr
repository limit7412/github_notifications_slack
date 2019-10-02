require "json"

class GithubComment
  JSON.mapping(
    user: {
      type:    GithubUser,
      nilable: true,
    },
    title_link: {
      type:    String,
      nilable: true,
    },
    body: {
      type:    String,
      nilable: true,
    },
  )
end

class GithubUser
  JSON.mapping(
    login: {
      type:    String,
      nilable: true,
    },
    avatar_url: {
      type:    String,
      nilable: true,
    },
    html_url: {
      type:    String,
      nilable: true,
    },
  )
end