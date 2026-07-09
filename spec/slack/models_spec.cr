require "../spec_helper"

describe Slack::Attachment do
  it "omits unset fields when serialized" do
    json = Slack::Attachment.new(text: "hello", color: "#000000").to_json
    parsed = JSON.parse(json)

    parsed["text"].should eq "hello"
    parsed["color"].should eq "#000000"
    parsed.as_h.has_key?("title").should be_false
  end

  describe ".from_message" do
    it "prefixes the pretext with a mention when the message mentions the user" do
      message = Notify::Message.new(mention: true, pretext: "hello", text: "body")
      attachment = Slack::Attachment.from_message(message, "U123")

      attachment.pretext.should eq "<@U123> hello"
      # fallback は生の pretext を保持する
      attachment.fallback.should eq "hello"
    end

    it "leaves the pretext untouched when the message does not mention" do
      message = Notify::Message.new(mention: false, pretext: "hello")
      attachment = Slack::Attachment.from_message(message, "U123")

      attachment.pretext.should eq "hello"
    end
  end
end

describe Slack::Post do
  it "wraps attachments under an attachments key" do
    post = Slack::Post.new([Slack::Attachment.new(text: "a")])
    parsed = JSON.parse(post.to_json)

    parsed["attachments"].as_a.size.should eq 1
    parsed["attachments"][0]["text"].should eq "a"
  end

  describe ".build" do
    it "converts every message to an attachment" do
      messages = [
        Notify::Message.new(pretext: "first"),
        Notify::Message.new(pretext: "second"),
      ]
      post = Slack::Post.build(messages, "U123")

      post.attachments.size.should eq 2
      post.attachments[0].pretext.should eq "first"
      post.attachments[1].pretext.should eq "second"
    end
  end
end
