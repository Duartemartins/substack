# lib/substack/endpoints.rb

module Substack
  # The Endpoints module contains constants for all Substack API endpoints.
  # These are used throughout the gem to make API requests.
  #
  # Most endpoints are relative to the base API URL, but some (like POSTS_FEED)
  # are specific to a publication domain.
  module Endpoints
    # Base API URL for Substack
    API = 'https://substack.com/api/v1'.freeze

    # Get the user's following feed (logged-in home feed)
    FEED_FOLLOWING  = "#{API}/feed/following".freeze
    
    # Get the user's inbox notifications (Notes, replies, mentions)
    INBOX_TOP       = "#{API}/inbox/top".freeze
    
    # Mark cards as read in the inbox
    INBOX_SEEN      = "#{API}/inbox/seen".freeze
    
    # Get scheduled audio rooms
    LIVE_STREAMS    = "#{API}/live_streams/active".freeze
    
    # Get unread message counts (DM + chat badge counter)
    UNREAD_COUNT    = "#{API}/messages/unread-count".freeze
    
    # Binary image upload endpoint for Notes
    IMAGE_UPLOAD    = "#{API}/image".freeze
    
    # Convert image URL to attachment ID for use in Notes
    ATTACH_IMAGE    = "#{API}/comment/attachment".freeze
    
    # Create a Note (text + attachments)
    POST_NOTE       = "#{API}/comment/feed".freeze
    
    # React to a Note (like, etc.)
    # @param id [String] The ID of the Note to react to
    # @return [String] The full API endpoint for reacting to the specified Note
    REACT_NOTE      = -> id { "#{API}/comment/#{id}/reaction" }
    
    # Update user settings (last_home_tab, etc.)
    USER_SETTING    = "#{API}/user-setting".freeze
    
    # Get public post feed (no auth required)
    # @param pub [String] The publication subdomain
    # @return [String] The full API endpoint for the publication's posts
    POSTS_FEED      = -> pub { "https://#{pub}.substack.com/api/v1/posts" }
  end
end
