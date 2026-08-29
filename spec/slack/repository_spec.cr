require "../spec_helper"
require "../../src/slack/repository"

# 送信された本文を記録するだけの webhook クライアント。
# fail_at 番目（0 始まり）の送信で例外を投げ、送信失敗を再現する。
private class RecordingClient < Webhook::Client
  getter bodies = [] of String

  def initialize(@fail_at : Int32? = nil)
    super("slack", "https://example.com/webhook")
  end

  def post(body : String)
    raise "send failed" if @fail_at == @bodies.size
    @bodies << body
  end
end

private def messages(count)
  Array.new(count) { Notify::Message.new(pretext: "pre") }
end

describe Slack::PostRepository do
  describe "#send_messages" do
    it "sends every message as one post and yields the total" do
      client = RecordingClient.new
      sent = [] of Int32
      Slack::PostRepository.new(client).send_messages(messages(3)) { |count| sent << count }

      client.bodies.size.should eq 1
      Slack::Post.from_json(client.bodies.first).attachments.size.should eq 3
      sent.should eq [3]
    end

    # 投稿できていない通知を既読化させないため、失敗時は yield させない。
    it "does not yield when the post fails" do
      client = RecordingClient.new(fail_at: 0)
      sent = [] of Int32

      expect_raises(Exception, "send failed") do
        Slack::PostRepository.new(client).send_messages(messages(2)) { |count| sent << count }
      end

      sent.should be_empty
    end
  end
end
