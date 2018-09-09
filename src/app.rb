require 'json'
require 'net/http'
require 'uri'

require 'octokit'

client = Octokit::Client.new access_token: ENV['GITHUB_TOKEN']

def get_notifications(client)
  notifications = client
    .notifications({all: true, since: '2016-01-06T23:39:01Z'})
    .map{ |notice| {
        type: notice.subject.type,
        reason: notice.reason,
      }
    }

  return notifications
end


def decision_type(type)
  subject = ''
  app = 'rin'
  if type == 'PullRequest'
    subject = 'プルリクエストみたいです！\n一緒にレビューがんばりましょう！\n'
    app = 'uduki'
  elsif  type == 'Issue'
    subject = 'イシューみたい\n確認してみよっか\n'
    app = 'rin'
  else
    subject = "なにかあったみたい\n #{type}だって\n"
    app = 'rin'
  end

  return {
    subject: subject,
    app: app,
  }
end

def decision_reason(reason)
  mention = ''
  if reason == 'assign'    ||
     reason == 'author'    ||
     reason == 'comment'   ||
     reason == 'invitation'
    mention = "<@#{ENV['SLACK_ID']}>"
  end

  return {
    mention: mention,
  }
end

def api_post(params)
  uri = URI.parse(ENV['WEBHOOK_URL'])
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.start do
    request = Net::HTTP::Post.new(uri.path)
    request.set_form_data(payload: params.to_json)
    http.request(request)
  end
end

# loop do
  notifications =  get_notifications(client)
  .map{ |notice| notice.merge( decision_type(notice[:type]) ) }
  .map{ |notice| notice.merge( decision_reason(notice[:reason]) ) }

  # notifications.each do |params|
  #   api_post(params)
  # end
  # api_post(notifications[0])
  puts notifications[0]
# end
