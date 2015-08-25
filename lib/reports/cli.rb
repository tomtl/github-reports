require 'rubygems'
require 'bundler/setup'
require 'thor'
require 'dotenv'
Dotenv.load

require 'reports/github_api_client'
require 'reports/table_printer'

module Reports

  class CLI < Thor

    desc "console", "Open an RB session with all dependencies loaded and API defined."
    def console
      require 'irb'
      ARGV.clear
      IRB.start
    end

    desc "user_info USERNAME", "Get information for a user"
    def user_info(username)
      puts "Getting info for #{username}..."

      client = GitHubAPIClient.new(ENV['GITHUB_TOKEN'])
      user = client.user_info(username)

      puts "name: #{user.name}"
      puts "location: #{user.location}"
      puts "public repos: #{user.public_repos}"
    rescue Error => error
      puts "Error #{error.message}"
      exit 1
    end

    desc "repositories USERNAME", "Load the repo stats for USERNAME"
    def repositories(username)
      puts "Getting public repositories for #{username}..."

      client = GitHubAPIClient.new(ENV['GITHUB_TOKEN'])
      repos = client.user_repos(username)

      puts "#{username} has #{repos.size} public repos. \n\n"
      repos.each { |repo| puts "#{repo.name} - #{repo.url}" }
    rescue Error => error
      puts "Error #{error.message}"
      exit 1
    end

    private

    def client
      @client ||= GitHubAPIClient.new
    end

  end

end
