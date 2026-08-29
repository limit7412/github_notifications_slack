require "../spec_helper"
require "../../src/webhook/client"

# HTTP を張らずに、あらかじめ用意した応答を順に返すクライアント。
# 応答を使い切ったあとは最後の応答を返し続ける。
private class StubClient < Webhook::Client
  getter attempts = 0

  def initialize(@responses : Array(HTTP::Client::Response))
    super("stub", "https://example.com/webhook")
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

describe Webhook::Client do
  describe "#post" do
    it "sends once when the webhook succeeds" do
      client = StubClient.new([response(200)])
      client.post "{}"

      client.attempts.should eq 1
    end

    it "retries a rate limit and returns once it succeeds" do
      client = StubClient.new([response(429), response(200)])
      client.post "{}"

      client.attempts.should eq 2
    end

    it "retries a server error and returns once it succeeds" do
      client = StubClient.new([response(500), response(200)])
      client.post "{}"

      client.attempts.should eq 2
    end

    # 失敗を握りつぶすと、投稿されていない通知まで呼び出し側が既読化する。
    it "raises after exhausting the attempts on a rate limit" do
      client = StubClient.new([response(429)])

      expect_raises(Exception, /stub webhook returned 429/) { client.post "{}" }

      client.attempts.should eq Webhook::Client::MAX_SEND_ATTEMPTS
    end

    it "raises after exhausting the attempts on a server error" do
      client = StubClient.new([response(500)])

      expect_raises(Exception, /stub webhook returned 500/) { client.post "{}" }

      client.attempts.should eq Webhook::Client::MAX_SEND_ATTEMPTS
    end

    # 再送しても通らないため、そのまま例外にする。
    it "does not retry a permanent client error" do
      client = StubClient.new([response(404)])

      expect_raises(Exception, /stub webhook returned 404/) { client.post "{}" }

      client.attempts.should eq 1
    end

    # Retry-After が無い応答でも待機上限を超えないこと。
    it "caps the wait when the webhook sends no Retry-After" do
      client = StubClient.new([response(429, retry_after: nil), response(200)])
      started = Time.monotonic
      client.post "{}"

      (Time.monotonic - started).should be < Webhook::Client::MAX_RETRY_WAIT
    end
  end
end
