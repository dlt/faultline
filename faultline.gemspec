# frozen_string_literal: true

require_relative "lib/faultline/version"

Gem::Specification.new do |spec|
  spec.name        = "faultline"
  spec.version     = Faultline::VERSION
  spec.authors     = ["dlt"]
  spec.email       = ["dlt@users.noreply.github.com"]
  spec.homepage    = "https://github.com/dlt/faultline"
  spec.summary     = "Self-hosted error tracking for Rails 8+"
  spec.description = <<~DESC
    Faultline is a self-hosted error tracking engine for Rails applications.
    Track errors with local variable capture, get notified via Telegram/Slack/Resend/webhooks,
    and resolve issues with a clean dashboard UI—all without external services or SaaS fees.
  DESC
  spec.license     = "MIT"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "documentation_uri" => "#{spec.homepage}#readme",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,lib}/**/*", "MIT-LICENSE", "CHANGELOG.md", "README.md"]
  end

  spec.required_ruby_version = ">= 3.2.0"

  spec.add_dependency "rails", ">= 8.0"

  spec.add_development_dependency "rspec-rails", "~> 7.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "factory_bot_rails", "~> 6.4"
  spec.add_development_dependency "sqlite3", "~> 2.0"
end
