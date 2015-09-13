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
    option :forks,
           type: :boolean,
           desc: "Include forks in stats",
           default: false

    def repositories(username)
      puts "Getting public repositories for #{username}..."

      client = GitHubAPIClient.new
      repos = client.user_repos(username, forks: options[:forks])

      puts "#{username} has #{repos.size} public repos. \n\n"

      table_printer = TablePrinter.new(STDOUT)

      repos.each do |repo|
        table_printer.print(repo.languages, title: repo.name, humanize: true)
        puts # blank line
      end

      stats = Hash.new(0)
      repos.each do |repo|
        repo.languages.each_pair do |language, bytes|
          stats[language] += bytes
        end
      end

      table_printer.print(
        stats,
        title: "Language Summary",
        humanize: true, total: true
      )

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

    desc "gist FILE", "Create a gist from a file"
    def create_gist(file)
      puts "Creating a gist..."
      client = GitHubAPIClient.new
      gist = client.create_gist(file)
      puts "Gist created: #{gist.url}"
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
      push_events_map = push_events.each_with_object(Hash.new(0)) do |event, counts|
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
