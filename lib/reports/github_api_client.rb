require "faraday"
require "json"
require "logger"

module Reports

  class Error < StandardError; end
  class AuthenticationFailure < Error; end
  class NonexistentUser < Error; end
  class RequestFailure < Error; end

  User = Struct.new(:name, :location, :public_repos)
  VALID_STATUS_CODES = [200, 302, 401, 403, 404, 422]

  class GitHubAPIClient
    def initialize(token)
      @logger = Logger.new(STDOUT)

      @logger.formatter = proc do |severity, datetime, progname, msg|
        msg + "\n"
      end

      @token = token
    end

    def user_info(username)
      headers = {"Authorization" => "token #{@token}"}
      url = "https://api.github.com/users/#{username}"

      start_time = Time.now
      response = Faraday.get(url, nil, headers)
      duration = Time.now - start_time

      @logger.debug "-> %s %s %d (%.3f s)" % [url, "GET", response.status, duration]

      if !VALID_STATUS_CODES.include? response.status
        raise RequestFailure, JSON.parse(response.body)["message"]
      end

      if response.status == 401
        raise AuthenticationFailure, "Authentication Failed. Please set the 'GITHUB_TOKEN' environment variable to a valid Github access token."
      end

      if response.status == 404
        raise NonexistentUser, "'#{username}' does not exist"
      end

      data = JSON.parse(response.body)
      User.new(data["name"], data["location"], data["public_repos"])
    end
  end

end
