require "clim"
require "./worker.cr"

module GithubNotificationsSlack
  class Cli < Clim
    VERSION = "0.1.0"

    main do
      version "version: #{VERSION}", short: "-v"
      option "-b", "--bool-test",
        type: Bool,
        desc: "hoge."

      run do |opts, args|
        worker = Worker.new

        if opts.bool_test
          worker.run
        else
          worker.run
        end
      end
    end
  end
end

GithubNotificationsSlack::Cli.start(ARGV)
