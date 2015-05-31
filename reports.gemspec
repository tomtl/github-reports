$:.push File.expand_path("../lib", __FILE__)

require 'reports'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "reports"
  s.version     = Reports::VERSION
  s.summary     = "Reports built using the GitHub API"
  s.authors     = "A Swift Fox"

  s.files = Dir["lib/**/*", "Rakefile", "README.md"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "activesupport"
  s.add_dependency "thor"
  s.add_dependency "redis"
  s.add_dependency "dalli"
  s.add_dependency "dotenv"

  s.add_development_dependency "rake"
  s.add_development_dependency "sinatra"
  s.add_development_dependency "vcr"
  s.add_development_dependency "rspec"
  s.add_development_dependency "webmock"
end

