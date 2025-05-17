# lib/substack_api.rb
require_relative "substack_api/version"

# = Substack API Wrapper
# 
# A Ruby wrapper for the unofficial Substack API. This gem provides methods for
# authenticating with Substack, creating and publishing posts, interacting with Notes,
# and accessing various Substack features.
#
# == Example Usage
#
#   # Initialize client with authentication
#   client = Substack::Client.new(email: 'email@example.com', password: 'password')
#   
#   # Or use previously saved cookies
#   client = Substack::Client.new
#   
#   # Create and publish a post
#   post = Substack::Post.new(title: 'My Post', subtitle: 'Subtitle', user_id: client.get_user_id)
#   post.paragraph('This is a test paragraph.')
#   client.post_draft(post.get_draft)
#
module Substack
  require_relative "substack_api/errors"
  require_relative "substack_api/endpoints"
  require_relative "substack_api/client"
  require_relative "substack_api/post"
end