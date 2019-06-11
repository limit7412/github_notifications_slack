require "clim"
require "./app.cr"

module GithubNotificationsSlack
  class Cli < Clim
    VERSION = "0.1.0"

    main do
      version "version: #{VERSION}", short: "-v"
      option "-b", "--bool-test",
        type: Bool,
        desc: "hoge."

      run do |opts, args|
        app = App.new

        if opts.bool_test
          app.run
        else
          app.run
        end
      end
    end
  end
end

GithubNotificationsSlack::Cli.start(ARGV)
