require "./models"
require "./repository"
require "../slack/models"

module Github
  class Usecase
    def to_slack_attachment(notify : Notifications, pretext : String, message : String) : Slack::Attachment
      repo = NotificationRepository.new ENV["GITHUB_TOKEN"]

      comment = repo.get_comment notify.subject.comment_url
      Slack::Attachment.new(
        fallback: pretext,
        author_name: comment.user.login,
        author_icon: comment.user.avatar_url,
        author_link: comment.user.html_url,
        pretext: "#{notify.mention? ? "<@#{ENV["SLACK_ID"]}> " : ""}#{pretext}",
        color: notify.subject.color,
        title: notify.subject.title,
        title_link: comment.html_url,
        text: comment.body,
        footer: !notify.repository.full_name.nil? ? notify.repository.full_name : "github",
        footer_icon: notify.repository.owner.avatar_url,
      )
    end
  end
end
