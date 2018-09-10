require 'json'
require 'pp'
require "faraday"
require 'uri'

require 'octokit'

client = Octokit::Client.new access_token: ENV['GITHUB_TOKEN']

def get_notifications(client)
  return client
    .notifications #({all: true, since: '2016-01-06T23:39:01Z'})
    .map{ |notice| {
        type: notice.subject.type,
        reason: notice.reason,
        repository_name: notice.repository.full_name,
        title: notice.subject.title,
        avatar: notice.repository.owner.avatar_url,
        comment_url: notice.subject.url,
        subscription_url: notice.subscription_url,
      }
    }
end


def decision_type(type)
  subject = ''
  app = 'rin'
  if type == 'PullRequest'
    subject = 'プルリクエストみたいです！ 一緒にレビューがんばりましょう！'
    app = 'uduki'
  elsif  type == 'Issue'
    subject = 'イシューみたい 確認してみよっか'
    app = 'rin'
  else
    subject = "なにかあったみたい #{type}だって"
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
    mention = "<@#{ENV['SLACK_ID']}> "
  end

  return {
    mention: mention,
  }
end

def get_footer(name)
  footer = ''
  if !name.nil?
    footer = name
  else
    footer = 'github'
  end

  return {
    footer: footer,
  }
end

def get_body(url)
  res = api_get(url,ENV['GITHUB_TOKEN'])
  return {
    author_name: res['user']['login'],
    author_icon: res['user']['avatar_url'],
    author_url: res['user']['html_url'],
    body: res['body'],
  }
end

def create_post(notice)
  return {
    post: {
      fallback: notice[:subject],
      author_name: notice[:author_name],
      author_icon: notice[:author_icon],
      pretext: "#{notice[:mention]}#{notice[:subject]}",
      color: "#A9D0F5",
      fields: [{
        title: notice[:title],
        value: notice[:body],
      }],
      footer: notice[:footer],
      footer_icon: notice[:avatar],
    }
  }
end

def api_get(url,token)
  uri = URI.parse url
  conn = Faraday::Connection.new(:url => uri) do |builder|
    # github
    builder.use Faraday::Request::BasicAuthentication, "",token
    builder.use Faraday::Adapter::NetHttp
  end
  res = conn.get
  return JSON.load res.body
end

def api_post(url,params)
  res = Faraday.post url, params.to_json
  return res.body
end

# loop do
  notifications =  get_notifications(client)
  .map{ |notice| notice.merge( decision_type(notice[:type]) ) }
  .map{ |notice| notice.merge( decision_reason(notice[:reason]) ) }
  .map{ |notice| notice.merge( get_footer(notice[:repository_name]) ) }
  .map{ |notice| notice.merge( get_body(notice[:comment_url]) ) }
  .map{ |notice| notice.merge( create_post(notice) ) }

  if !notifications.empty?
    notifications.each do |notice|
      # pp notice[:author]
      puts api_post(ENV['WEBHOOK_URL'],attachments:[notice[:post]])
    end
    # api_post(ENV['WEBHOOK_URL'],attachments:[notifications[0][:post]])
  end
# end
