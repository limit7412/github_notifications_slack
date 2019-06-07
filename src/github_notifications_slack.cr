require "clim"

module GithubNotificationsSlack
  class Cli < Clim
    VERSION = "0.1.0"

    main do
      run do |opts, args|
        puts "Hello world!! #{args.join(", ")}!"
      end
    end
  end
end

GithubNotificationsSlack::Cli.start(ARGV)
