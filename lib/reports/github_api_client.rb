require "faraday"
require "json"
require "logger"

module Reports

  User = Struct.new(:name, :location, :public_repos)

  class GitHubAPIClient
    def initialize
      @logger = Logger.new(STDOUT)
      @logger.formatter = proc do |severity, datetime, progname, msg|
        msg + "\n"
      end
    end
    
    def user_info(username)
      url = "https://api.github.com/users/#{username}"

      start_time = Time.now
      response = Faraday.get url
      duration = Time.now - start_time

      @logger.debug "-> %s %s %d (%.3f s)" % [url, "GET", response.status, duration]

      data = JSON.parse(response.body)
      User.new(data["name"], data["location"], data["public_repos"])
    end
  end

end
