require "clim"

module GithubNotificationsSlack
  class Cli < Clim
    VERSION = "0.1.0"

    main do
      version "version: #{VERSION}", short: "-v"
      # option "-t NAME", "--test=NAME",
      #   type: String,
      #   desc: "test.",
      #   required: true
      # option "-b", "--bool-test",
      #   type: Bool,
      #   desc: "hoge."

      run do |opts, args|
        # if opts.bool_test
        #   puts "bool"
        # end
        # puts "#{opts.test}."
        puts "test"
      end
    end
  end
end

GithubNotificationsSlack::Cli.start(ARGV)
