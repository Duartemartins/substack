require_relative 'test_helper'

class EndpointsTest < Minitest::Test
  def test_constant_endpoints
    # Test that base API constant is correctly defined
    assert_equal 'https://substack.com/api/v1', Substack::Endpoints::API
    
    # Test static endpoint constants
    assert_equal 'https://substack.com/api/v1/feed/following', Substack::Endpoints::FEED_FOLLOWING
    assert_equal 'https://substack.com/api/v1/inbox/top', Substack::Endpoints::INBOX_TOP
    assert_equal 'https://substack.com/api/v1/inbox/seen', Substack::Endpoints::INBOX_SEEN
    assert_equal 'https://substack.com/api/v1/live_streams/active', Substack::Endpoints::LIVE_STREAMS
    assert_equal 'https://substack.com/api/v1/messages/unread-count', Substack::Endpoints::UNREAD_COUNT
    assert_equal 'https://substack.com/api/v1/image', Substack::Endpoints::IMAGE_UPLOAD
    assert_equal 'https://substack.com/api/v1/comment/attachment', Substack::Endpoints::ATTACH_IMAGE
    assert_equal 'https://substack.com/api/v1/comment/feed', Substack::Endpoints::POST_NOTE
    assert_equal 'https://substack.com/api/v1/user-setting', Substack::Endpoints::USER_SETTING
  end
  
  def test_dynamic_endpoints
    # Test dynamic endpoints that are lambdas
    assert_equal 'https://substack.com/api/v1/comment/note123/reaction', Substack::Endpoints::REACT_NOTE.call('note123')
    assert_equal 'https://example.substack.com/api/v1/posts', Substack::Endpoints::POSTS_FEED.call('example')
  end
  
  def test_dynamic_endpoint_with_special_chars
    # Test with special characters to ensure proper encoding
    note_id = 'abc-123+456_789'
    assert_equal "https://substack.com/api/v1/comment/#{note_id}/reaction", Substack::Endpoints::REACT_NOTE.call(note_id)
    
    # Test with a publication domain containing hyphens
    pub_domain = 'my-awesome-blog'
    assert_equal "https://#{pub_domain}.substack.com/api/v1/posts", Substack::Endpoints::POSTS_FEED.call(pub_domain)
  end
end
