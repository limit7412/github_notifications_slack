require "../spec_helper"

describe Discord::Embed do
  describe ".color_from_hex" do
    it "converts a #RRGGBB string to its integer value" do
      Discord::Embed.color_from_hex("#F6CEE3").should eq 0xF6CEE3
      Discord::Embed.color_from_hex("000000").should eq 0
      Discord::Embed.color_from_hex("#ffffff").should eq 0xFFFFFF
    end

    it "returns nil for a missing or invalid color" do
      Discord::Embed.color_from_hex(nil).should be_nil
      Discord::Embed.color_from_hex("#notacolor").should be_nil
    end
  end

  describe ".from_message" do
    it "uses only the comment body as the description (pretext goes to content)" do
      message = Notify::Message.new(pretext: "pre", text: "body")
      embed = Discord::Embed.from_message(message)

      embed.description.should eq "body"
    end

    it "leaves description unset when there is no comment body" do
      embed = Discord::Embed.from_message(Notify::Message.new(pretext: "pre"))

      embed.description.should be_nil
    end

    it "drops author and footer when their required fields are absent" do
      embed = Discord::Embed.from_message(Notify::Message.new(title: "t"))

      embed.author.should be_nil
      embed.footer.should be_nil
    end

    it "builds author and footer from the message" do
      message = Notify::Message.new(
        author_name: "octocat",
        author_link: "https://example.com/u",
        author_icon: "https://example.com/a.png",
        footer: "octocat/Hello-World",
        footer_icon: "https://example.com/f.png",
      )
      embed = Discord::Embed.from_message(message)

      author = embed.author.as(Discord::Author)
      author.name.should eq "octocat"
      author.url.should eq "https://example.com/u"
      author.icon_url.should eq "https://example.com/a.png"

      footer = embed.footer.as(Discord::Footer)
      footer.text.should eq "octocat/Hello-World"
      footer.icon_url.should eq "https://example.com/f.png"
    end

    it "drops empty url / icon fields so Discord does not reject them" do
      # アラートは footer_icon: "" で来るため、空文字は nil として出さない
      message = Notify::Message.new(
        author_name: "octocat",
        author_link: "",
        author_icon: "",
        title_link: "",
        footer: "github",
        footer_icon: "",
      )
      embed = Discord::Embed.from_message(message)

      embed.url.should be_nil
      embed.author.as(Discord::Author).url.should be_nil
      embed.author.as(Discord::Author).icon_url.should be_nil
      embed.footer.as(Discord::Footer).icon_url.should be_nil

      # 空文字フィールドはシリアライズされない
      parsed = JSON.parse(embed.to_json)
      parsed["footer"].as_h.has_key?("icon_url").should be_false
    end

    it "truncates title and description to the Discord limits" do
      message = Notify::Message.new(
        title: "t" * (Discord::TITLE_LIMIT + 10),
        text: "d" * (Discord::DESCRIPTION_LIMIT + 10),
      )
      embed = Discord::Embed.from_message(message)

      embed.title.as(String).size.should eq Discord::TITLE_LIMIT
      embed.description.as(String).size.should eq Discord::DESCRIPTION_LIMIT
    end

    it "omits unset fields when serialized" do
      parsed = JSON.parse(Discord::Embed.from_message(Notify::Message.new(title: "t")).to_json)

      parsed["title"].should eq "t"
      parsed.as_h.has_key?("description").should be_false
      parsed.as_h.has_key?("author").should be_false
    end
  end
end

describe Discord::Post do
  describe ".build" do
    it "chunks messages into posts of at most 10 embeds" do
      messages = Array.new(23) { |i| Notify::Message.new(title: "t#{i}") }
      posts = Discord::Post.build(messages)

      posts.size.should eq 3
      posts[0].embeds.size.should eq 10
      posts[1].embeds.size.should eq 10
      posts[2].embeds.size.should eq 3
    end

    it "splits a chunk before the combined embed length exceeds 6000 chars" do
      # 1 embed = title(2) + description(2900) = 2902 文字。
      # 2 件で 5804 ≤ 6000 は同一メッセージ、3 件目で 8706 を超えるため分割される。
      messages = Array.new(3) { |i| Notify::Message.new(title: "t#{i}", text: "d" * 2900) }
      posts = Discord::Post.build(messages)

      posts.size.should eq 2
      posts[0].embeds.size.should eq 2
      posts[1].embeds.size.should eq 1
      posts.each do |post|
        post.embeds.sum(&.char_count).should be <= Discord::TOTAL_CHARS_LIMIT
      end
    end

    it "sets a channel-wide mention in content when any message in a chunk mentions" do
      messages = [
        Notify::Message.new(title: "a"),
        Notify::Message.new(title: "b", mention: true),
      ]
      posts = Discord::Post.build(messages)

      posts.size.should eq 1
      posts[0].content.should eq "@everyone"
    end

    it "leaves content unset when no message mentions" do
      posts = Discord::Post.build([Notify::Message.new(title: "a")])

      posts[0].content.should be_nil
    end

    it "outputs the bot serif (pretext) as content" do
      posts = Discord::Post.build([Notify::Message.new(title: "a", pretext: "[Issue] hi")])

      posts[0].content.should eq "[Issue] hi"
    end

    it "prepends the channel-wide mention before the serif" do
      posts = Discord::Post.build([Notify::Message.new(title: "a", pretext: "[Issue] hi", mention: true)])

      posts[0].content.should eq "@everyone\n[Issue] hi"
    end

    it "de-duplicates repeated serifs within a chunk while keeping order" do
      messages = [
        Notify::Message.new(title: "a", pretext: "[Issue] hi"),
        Notify::Message.new(title: "b", pretext: "[Issue] hi"),
        Notify::Message.new(title: "c", pretext: "[PullRequest] yo"),
      ]
      posts = Discord::Post.build(messages)

      posts.size.should eq 1
      posts[0].content.should eq "[Issue] hi\n[PullRequest] yo"
    end

    it "truncates content to the Discord content limit" do
      # 各セリフを異なる内容にして uniq でまとまらないようにする。
      messages = Array.new(3) { |i| Notify::Message.new(title: "t#{i}", pretext: "#{i}#{"p" * 900}") }
      posts = Discord::Post.build(messages)

      posts.size.should eq 1
      posts[0].content.as(String).size.should eq Discord::CONTENT_LIMIT
    end

    it "serializes embeds under an embeds key" do
      parsed = JSON.parse(Discord::Post.build([Notify::Message.new(title: "a")])[0].to_json)

      parsed["embeds"].as_a.size.should eq 1
      parsed["embeds"][0]["title"].should eq "a"
    end
  end
end
