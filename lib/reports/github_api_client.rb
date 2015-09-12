require "faraday"
require "json"
require "logger"
require "pry"

require_relative "middleware/logging"
require_relative "middleware/authentication"
require_relative "middleware/status_check"
require_relative "middleware/json_parsing"
require_relative "middleware/cache"
require_relative "storage/redis"

module Reports

  class Error < StandardError; end
  class AuthenticationFailure < Error; end
  class NonexistentUser < Error; end
  class RequestFailure < Error; end
  class ConfigurationError < Error; end

  User = Struct.new(:name, :location, :public_repos)
  Repo = Struct.new(:name, :url)
  Event = Struct.new(:type, :repo_name)

  class GitHubAPIClient
    def user_info(username)
      url = "https://api.github.com/users/#{username}"
      response = client.get(url)

      if response.status == 404
        raise NonexistentUser, "'#{username}' does not exist"
      end

      data = response.body
      User.new(data["name"], data["location"], data["public_repos"])
    end

    def user_repos(username)
      url = "https://api.github.com/users/#{username}/repos"
      response = client.get(url)

      if response.status == 404
        raise NonexistentUser, "'#{username}' does not exist"
      end

      repos = response.body

      link_header = response.headers["link"]

      if link_header
        while match_data = link_header.match(/<(.*)>; rel="next"/)
          next_page_url = match_data[1]
          response = client.get(next_page_url)
          link_header = response.headers["link"]
          repos += response.body
        end
      end

      repos.map do |repo_data|
        Repo.new(repo_data["full_name"], repo_data["url"])
      end
    end

    def public_events_for_user(username)
      url = "https://api.github.com/users/#{username}/events/public"
      response = client.get(url)

      if response.status != 200
        raise NonexistentUser, "'#{username}' does not exist"
      end

      events = response.body

      link_header = response.headers["link"]

      if link_header
        while match_data = link_header.match(/<(.*)>; rel="next"/)
          next_page_url = match_data[1]
          response = client.get(next_page_url)
          link_header = response.headers["link"]
          events += response.body
        end
      end

      events.map do |event_data|
        event_type = event_data["type"]
        repo_name = event_data["repo"]["name"] if event_data["repo"]["name"]
        Event.new(event_type, repo_name)
      end
    end

    def client
      @client ||= Faraday::Connection.new do |builder|
        builder.use Middleware::JSONParsing
        builder.use Middleware::StatusCheck
        builder.use Middleware::Authentication
        builder.use Middleware::Logging
        builder.use Middleware::Cache, Storage::Redis.new
        builder.adapter Faraday.default_adapter
      end
    end
  end
end
