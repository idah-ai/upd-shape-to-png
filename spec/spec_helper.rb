# frozen_string_literal: true

# Load the main script so all classes are available
require_relative "../main"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Clean up any temp output between tests to avoid interference
  config.after(:suite) do
    tmpdir = File.join(__dir__, "..", "tmp_test_output")
    FileUtils.rm_rf(tmpdir)
  end
end

# Helper to create a temporary output directory for PNG writer tests
def test_output_dir
  dir = File.join(__dir__, "..", "tmp_test_output")
  FileUtils.mkdir_p(dir)
  dir
end