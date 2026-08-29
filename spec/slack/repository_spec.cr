require "../spec_helper"
require "../../src/slack/repository"

# HTTP を張らずに、あらかじめ用意した応答を順に返す送信先。
# 応答を使い切ったあとは最後の応答を返し続ける。
private class StubPostRepository < Slack::PostRepository
  getter attempts = 0

  def initialize(@responses : Array(HTTP::Client::Response))
    super("https://example.com/webhook")
  end

  private def post_json(_body : String) : HTTP::Client::Response
    @attempts += 1
    @responses[@attempts - 1]? || @responses.last
  end
end

# Retry-After を 0 にして、待機でテストが遅くならないようにする。
private def response(status : Int32, retry_after : String? = "0")
  headers = HTTP::Headers.new
  headers["Retry-After"] = retry_after if retry_after
  HTTP::Client::Response.new(status, body: "", headers: headers)
end

private def messages(count = 1)
  Array.new(count) { Notify::Message.new(pretext: "pre") }
end

describe Slack::PostRepository do
  describe "#send_messages" do
    it "sends once and yields the total when the webhook succeeds" do
      poster = StubPostRepository.new([response(200)])
      sent = [] of Int32
      poster.send_messages(messages(3)) { |count| sent << count }

      poster.attempts.should eq 1
      sent.should eq [3]
    end

    # 応答を検査しないと、投稿されていない通知まで呼び出し側が既読化して
    # 通知が消える。失敗時は yield させず例外にする（issue #120）。
    it "raises without yielding when the webhook keeps rate limiting" do
      poster = StubPostRepository.new([response(429)])
      sent = [] of Int32

      expect_raises(Exception, /slack webhook returned 429/) do
        poster.send_messages(messages(2)) { |count| sent << count }
      end

      poster.attempts.should eq Slack::PostRepository::MAX_SEND_ATTEMPTS
      sent.should be_empty
    end

    it "raises without yielding when the webhook returns a server error" do
      poster = StubPostRepository.new([response(500)])
      sent = [] of Int32

      expect_raises(Exception, /slack webhook returned 500/) do
        poster.send_messages(messages(2)) { |count| sent << count }
      end

      sent.should be_empty
    end

    it "yields after a retried rate limit succeeds" do
      poster = StubPostRepository.new([response(429), response(200)])
      sent = [] of Int32
      poster.send_messages(messages(2)) { |count| sent << count }

      poster.attempts.should eq 2
      sent.should eq [2]
    end

    # 恒久的な失敗を再送しても通らないため、そのまま例外にする。
    it "does not retry a permanent client error" do
      poster = StubPostRepository.new([response(404)])
      sent = [] of Int32

      expect_raises(Exception, /slack webhook returned 404/) do
        poster.send_messages(messages) { |count| sent << count }
      end

      poster.attempts.should eq 1
      sent.should be_empty
    end

    # Retry-After が無い応答でも待機上限を超えないこと。
    it "caps the wait when the webhook sends no Retry-After" do
      poster = StubPostRepository.new([response(429, retry_after: nil), response(200)])
      started = Time.monotonic
      poster.send_messages(messages) { }

      (Time.monotonic - started).should be < Slack::PostRepository::MAX_RETRY_WAIT
    end
  end
end
