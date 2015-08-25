require "faraday"
require "json"
require "logger"
require_relative "middleware/logging"

module Reports

  class Error < StandardError; end
  class AuthenticationFailure < Error; end
  class NonexistentUser < Error; end
  class RequestFailure < Error; end

  User = Struct.new(:name, :location, :public_repos)
  Repo = Struct.new(:name, :url)

  VALID_STATUS_CODES = [200, 302, 401, 403, 404, 422]

  class GitHubAPIClient
    def initialize(token)
      @token = token
    end

    def user_info(username)
      headers = {"Authorization" => "token #{@token}"}
      url = "https://api.github.com/users/#{username}"

      response = connection.get(url, nil, headers)

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

    def user_repos(username)
      headers = {"Authorization" => "token #{@token}"}
      url = "https://api.github.com/users/#{username}/repos"

      response = connection.get(url, nil, headers)

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
      data.map { |repo_data| Repo.new(repo_data["full_name"], repo_data["url"]) }
    end

    def connection
      @connection ||=  Faraday::Connection.new do |builder|
        builder.use Middleware::Logging
        builder.adapter Faraday.default_adapter
      end
    end
  end

end
