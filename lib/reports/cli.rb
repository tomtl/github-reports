require "rubygems"
require "bundler/setup"
require "thor"
require "dotenv"
require "time"
Dotenv.load

require "reports/github_api_client"
require "reports/table_printer"

module Reports

  class CLI < Thor

    desc "console", "Open an RB session with all dependencies loaded and API defined."
    def console
      require "irb"
      ARGV.clear
      IRB.start
    end

    desc "user_info USERNAME", "Get information for a user"
    def user_info(username)
      puts "Getting info for #{username}..."

      client = GitHubAPIClient.new
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

      client = GitHubAPIClient.new
      repos = client.user_repos(username)

      puts "#{username} has #{repos.size} public repos. \n\n"

      repos.each do |repo| 
        puts "#{repo.name}: #{repo.languages.keys.join(', ')}"
      end

    rescue Error => error
      puts "Error #{error.message}"
      exit 1
    end

    desc "activity USERNAME", "Summarize the activity of GitHub user USERNAME"
    def activity(username)
      puts "Getting events for #{username}..."
      client = GitHubAPIClient.new
      events = client.public_events_for_user(username)
      print_activity_report(events)
    rescue Error => error
      puts "Error #{error.message}"
      exit 1
    end

    private

    def client
      @client ||= GitHubAPIClient.new
    end

    def print_activity_report(events)
      table_printer = TablePrinter.new(STDOUT)
      event_types_map = events.each_with_object(Hash.new(0)) do |event, counts|
        counts[event.type] += 1
      end

      table_printer.print(event_types_map, title: "Event Summary", total: true)
      push_events = events.select { |event| event.type == "PushEvent" }
      push_events_map = push_events.each_with_object(Hash.new(0)) do
        |event, counts|
        counts[event.repo_name] += 1
      end

      puts # blank line
      table_printer.print(
        push_events_map,
        title: "Project Push Summary", total: true
      )
    end
  end

end
