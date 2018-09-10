require 'json'
require 'pp'
require "faraday"
require 'uri'

require 'octokit'

client = Octokit::Client.new access_token: ENV['GITHUB_TOKEN']

def get_notifications(client)
  return client
    .notifications({all: true, since: '2015-09-07T23:39:01Z'})
    .map{ |notice| {
        type: notice.subject.type,
        reason: notice.reason,
        repository_name: notice.repository.full_name,
        title: notice.subject.title,
        title_link: notice.repository.html_url,
        avatar: notice.repository.owner.avatar_url,
        comment_url: notice.subject.url,
        latest_url: notice.subject.latest_comment_url,
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
    mention = "<#{ENV['SLACK_ID']}> "
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

def get_body(comment_url,latest_url)
  body = ''
  if latest_url.nil?
    body = get_comment comment_url
  else
    body = get_comment latest_url
  end

  return body
end

def get_comment(url)
  res = api_get(url,ENV['GITHUB_TOKEN'])
  author_name = ''
  author_icon = ''
  author_link = ''
  if !res['user'].nil?
    author_name = res['user']['login']
    author_icon = res['user']['avatar_url']
    author_link = res['user']['html_url']
  end

  return {
    author_name: author_name,
    author_icon: author_icon,
    author_link: author_link,
    title_link: res['html_url'],
    body: res['body'],
  }
end

def create_post(notice)
  return {
    post: {
      fallback: notice[:subject],
      author_name: notice[:author_name],
      author_icon: notice[:author_icon],
      author_link: notice[:author_link],
      pretext: "#{notice[:mention]}#{notice[:subject]}",
      color: "#A9D0F5",
      title: notice[:title],
      title_link: notice[:title_link],
      text: notice[:body],
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

def api_put(url,token)
  uri = URI.parse url
  conn = Faraday::Connection.new(:url => uri) do |builder|
    # github
    builder.use Faraday::Request::BasicAuthentication, "",token
    builder.use Faraday::Adapter::NetHttp
  end
  res = conn.put
  return res.status
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
  .map{ |notice| notice.merge( get_body( notice[:comment_url], notice[:latest_url] ) ) }
  .map{ |notice| notice.merge( create_post(notice) ) }

  if !notifications.empty?
    notifications.each do |notice|
      webhook = ''
      if notice[:app] == 'uduki'
        webhook = ENV['WEBHOOK_URL_UDUKI']
      elsif notice[:app] == 'rin'
        webhook = ENV['WEBHOOK_URL_RIN']
      end

      puts api_post(webhook,attachments:[notice[:post]])
      # puts api_put('https://api.github.com/notifications',ENV['GITHUB_TOKEN'])
    end
  end
# end
