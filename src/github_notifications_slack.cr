require "clim"
require "./worker.cr"

module GithubNotificationsSlack
  class Cli < Clim
    VERSION = "0.1.0"

    main do
      version "version: #{VERSION}", short: "-v"
      option "-c", "--continue",
        type: Bool,
        desc: "Continue to run."

      run do |opts, args|
        worker = Worker.new

        if opts.continue
          worker.run
        else
          worker.exec
        end
      end
    end
  end
end

GithubNotificationsSlack::Cli.start(ARGV)
