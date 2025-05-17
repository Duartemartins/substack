require 'simplecov'
SimpleCov.start do
  add_filter '/test/'  # Don't include test files in coverage
  add_group 'Client', 'lib/substack_api/client'
  add_group 'Core', 'lib/substack_api'
end

require 'minitest/autorun'
require 'minitest/reporters'
require 'mocha/minitest'

# Configure test environment
ENV['SUBSTACK_TEST_MODE'] = 'true'

# Add the lib directory to the load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

# First require the main gem
require 'substack'

# Then require our stub to extend functionality for testing
require_relative 'fixtures/test_client'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new