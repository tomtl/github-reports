require "faraday"
require "json"
require "logger"
require_relative "middleware/logging"
require_relative "middleware/authentication"
require_relative "middleware/status_check"
require_relative "middleware/json_parsing"
require_relative "middleware/cache"
require_relative "storage/memory"

module Reports

  class Error < StandardError; end
  class AuthenticationFailure < Error; end
  class NonexistentUser < Error; end
  class RequestFailure < Error; end

  User = Struct.new(:name, :location, :public_repos)
  Repo = Struct.new(:name, :url)

  class GitHubAPIClient
    def user_info(username)
      url = "https://api.github.com/users/#{username}"

      response = connection.get(url)

      if response.status == 404
        raise NonexistentUser, "'#{username}' does not exist"
      end

      data = response.body
      User.new(data["name"], data["location"], data["public_repos"])
    end

    def user_repos(username)
      url = "https://api.github.com/users/#{username}/repos"

      response = connection.get(url)

      if response.status == 404
        raise NonexistentUser, "'#{username}' does not exist"
      end

      data = response.body

      data.map do |repo_data|
        Repo.new(repo_data["full_name"], repo_data["url"])
      end
    end

    def connection
      @connection ||= Faraday::Connection.new do |builder|
        builder.use Middleware::StatusCheck
        builder.use Middleware::Authentication
        builder.use Middleware::JSONParsing
        builder.use Middleware::Cache, Storage::Memory.new
        builder.use Middleware::Logging
        builder.adapter Faraday.default_adapter
      end
    end
  end

end
