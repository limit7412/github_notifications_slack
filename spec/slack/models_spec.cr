require "../spec_helper"

describe Slack::Attachment do
  it "omits unset fields when serialized" do
    json = Slack::Attachment.new(text: "hello", color: "#000000").to_json
    parsed = JSON.parse(json)

    parsed["text"].should eq "hello"
    parsed["color"].should eq "#000000"
    parsed.as_h.has_key?("title").should be_false
  end
end

describe Slack::Post do
  it "wraps attachments under an attachments key" do
    post = Slack::Post.new([Slack::Attachment.new(text: "a")])
    parsed = JSON.parse(post.to_json)

    parsed["attachments"].as_a.size.should eq 1
    parsed["attachments"][0]["text"].should eq "a"
  end
end
