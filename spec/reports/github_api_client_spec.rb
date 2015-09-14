require "vcr_helper"
require "reports/github_api_client"

module Reports
  RSpec.describe GitHubAPIClient do
    describe "#user_info" do
      it "fetches info for a user", :vcr do
        client = GitHubAPIClient.new

        user = client.user_info("octocat")

        expect(user.name).to eq("The Octocat")
        expect(user.location).to eq("San Francisco")
        expect(user.public_repos).to eq(5)
      end

      it "raises an error for a nonexistent user" do
        client = GitHubAPIClient.new

        expect(->{
          client.user_info("nonexistent_username")
        }).to raise_error(NonexistentUser)
      end
    end
  end
end
