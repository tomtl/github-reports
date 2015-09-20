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
  class GistCreationFailure < Error; end

  User = Struct.new(:name, :location, :public_repos)
  Repo = Struct.new(:name, :languages)
  Event = Struct.new(:type, :repo_name)
  Gist = Struct.new(:url)
  Star = Struct.new(:owner, :repo)

  class GitHubAPIClient
    def initialize
      level = ENV["LOG_LEVEL"]
      @logger = Logger.new(STDOUT)

      @logger.formatter = proc do |severity, datetime, program, message|
        message +"\n"
      end

      @logger.level = Logger.const_get(level) if level
    end

    def user_info(username)
      url = "https://api.github.com/users/#{username}"
      response = connection.get(url)

      if response.status == 404
        raise NonexistentUser, "'#{username}' does not exist"
      end

      data = response.body
      User.new(data["name"], data["location"], data["public_repos"])
    end

    def user_repos(username, forks: forks)
      url = "https://api.github.com/users/#{username}/repos"
      response = connection.get(url)

      if response.status == 404
        raise NonexistentUser, "'#{username}' does not exist"
      end

      repos = response.body

      link_header = response.headers["link"]

      if link_header
        while match_data = link_header.match(/<(.*)>; rel="next"/)
          next_page_url = match_data[1]
          response = connection.get(next_page_url)
          link_header = response.headers["link"]
          repos += response.body
        end
      end

      repos.map do |repo_data|
        next if !forks && repo_data["fork"]

        full_name = repo_data["full_name"]
        language_url = "https://api.github.com/repos/#{full_name}/languages"
        response = connection.get(language_url)
        Repo.new(repo_data["full_name"], response.body)
      end.compact
    end

    def public_events_for_user(username)
      url = "https://api.github.com/users/#{username}/events/public"
      response = connection.get(url)

      if response.status == 404
        raise NonexistentUser, "'#{username}' does not exist"
      end

      events = response.body

      link_header = response.headers["link"]

      if link_header
        while match_data = link_header.match(/<(.*)>; rel="next"/)
          next_page_url = match_data[1]
          response = connection.get(next_page_url)
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

    def create_private_gist(description, file, content)
      url = "https://api.github.com/gists"
      body = {
        "description" => "#{description}",
        "public" => false,
        "files" => {
          "#{file}" => {
            "content" => "#{content}"
          }
        }
      }

      response = connection.post(url) do |request|
        request.body = body.to_json
      end

      if response.status == 201
        response.body["html_url"]
      else
        raise GistCreationFailure, "Gist not created"
      end
    end

    def star(owner, repo)
      url = "https://api.github.com/user/starred/#{owner}/#{repo}"

      response = connection.put(url) do |request|
        request.headers["Content-Length"] = "0"
      end
    end

    def connection
      @connection ||= Faraday::Connection.new do |builder|
        builder.use Middleware::JSONParsing
        builder.use Middleware::StatusCheck
        builder.use Middleware::Authentication
        builder.use Middleware::Logging
        builder.use Middleware::Cache, Storage::Redis.new
        builder.adapter Faraday.default_adapter
      end
    end

    # For HoneyProxy
    # def connection
    #   ca_path = File.expand_path("~/.mitmproxy/mitmproxy-ca-cert.pem")
    #   options = { proxy: 'https://localhost:8080',
    #               ssl: {ca_file: ca_path},
    #               url: "https://api.github.com" }
    #   @connection ||= Faraday::Connection.new(options) do |builder|
    #     builder.use Middleware::JSONParsing
    #     builder.use Middleware::StatusCheck
    #     builder.use Middleware::Authentication
    #     builder.use Middleware::Logging
    #     builder.use Middleware::Cache, Storage::Redis.new
    #     builder.adapter Faraday.default_adapter
    #   end
    # end
  end
end
