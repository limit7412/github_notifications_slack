require "../spec_helper"
require "../../src/discord/repository"

# 送信された本文を記録するだけの webhook クライアント。
# fail_at 番目（0 始まり）の送信で例外を投げ、送信失敗を再現する。
private class RecordingClient < Webhook::Client
  getter bodies = [] of String

  def initialize(@fail_at : Int32? = nil)
    super("discord", "https://example.com/webhook")
  end

  def post(body : String)
    raise "send failed" if @fail_at == @bodies.size
    @bodies << body
  end
end

private def messages(count)
  Array.new(count) { Notify::Message.new(pretext: "pre", title: "t") }
end

describe Discord::PostRepository do
  describe "#send_messages" do
    # embeds は 1 投稿 10 件までなので、12 件なら 2 投稿に分かれる。
    it "yields the running total after each post" do
      client = RecordingClient.new
      sent = [] of Int32
      Discord::PostRepository.new(client).send_messages(messages(12)) { |count| sent << count }

      client.bodies.size.should eq 2
      sent.should eq [10, 12]
    end

    # 送信済みの投稿までしか既読化させないため、失敗した投稿では yield しない。
    it "stops yielding at the post that fails" do
      client = RecordingClient.new(fail_at: 1)
      sent = [] of Int32

      expect_raises(Exception, "send failed") do
        Discord::PostRepository.new(client).send_messages(messages(12)) { |count| sent << count }
      end

      sent.should eq [10]
    end
  end
end
