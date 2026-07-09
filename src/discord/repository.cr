require "json"
require "uri"
require "http/client"
require "./models"
require "../notify/models"
require "../notify/poster"

module Discord
  class PostRepository < Notify::Poster
    def initialize(url : String, @mention_id : String)
      @uri = URI.parse url
      @client = HTTP::Client.new @uri
    end

    def send_messages(messages : Array(Notify::Message))
      Post.build(messages, @mention_id).each { |post| send_post post }
    end

    private def send_post(post : Post)
      res = @client.post(
        @uri.request_target,
        headers: HTTP::Headers{"Content-Type" => "application/json"},
        body: post.to_json,
      )
      # 429（レート制限）などの失敗時は例外にして既読化を止め、次回実行に委ねる。
      unless res.success?
        raise "discord webhook returned #{res.status_code}: #{res.body}"
      end
    end
  end
end
