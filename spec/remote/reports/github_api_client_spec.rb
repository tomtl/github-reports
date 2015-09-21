require "remote_helper"
require "reports/github_api_client"

module Reports
  RSpec.describe GitHubAPIClient, remote: true do
    describe "#user_info" do
      it "fetches info for a user" do
        client = GitHubAPIClient.new

        info = client.user_info("octocat")

        expect(info.name).to be_instance_of(String)
        expect(info.location).to be_instance_of(String)
        expect(info.public_repos).to be_instance_of(Fixnum)
      end

      it "raises an exception when a user doesn't exist" do
        client = GitHubAPIClient.new

        expect(->{
          client.user_info("auserthatdoesnotexist")
        }).to raise_error(NonexistentUser)
      end
    end
  end
end
