# frozen_string_literal: true

require "simplecov"
SimpleCov.start "rails" do
  add_filter "/spec/"
  add_filter "/lib/generators/"

  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Helpers", "app/helpers"
  add_group "Lib", "lib"
  add_group "Notifiers", "lib/faultline/notifiers"

  # Coverage thresholds can be increased as more tests are added
  minimum_coverage 30
  minimum_coverage_by_file 0
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = "doc" if config.files_to_run.one?

  config.order = :random
  Kernel.srand config.seed
end
