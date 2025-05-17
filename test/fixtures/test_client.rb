require 'minitest/autorun'
require 'mocha/minitest'

# This file adds test helper methods to the Substack::Client class
# It's loaded after the main gem in test_helper.rb so we can extend
# rather than override the existing methods

module Substack
  class Client
    # Test-specific helper methods
    module TestHelpers
      # Create a stub response for the request method
      def stub_request(endpoint, method: :get, response: {}, status: 200)
        # This will be used in tests to stub HTTP responses
        self.stubs(:request).with(endpoint, method: method).returns(response)
      end
    end
    
    # Add test helpers to the Client class
    include TestHelpers
  end
end
