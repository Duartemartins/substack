require_relative 'test_helper'

class ApiTest < Minitest::Test
  def setup
    # Use stub authentication from test_client.rb
    @client = Substack::Client.new
  end

  def test_following_feed
    mock_response = { 'posts' => [{'id' => 1}] }
    @client.expects(:request).with(:get, Substack::Endpoints::FEED_FOLLOWING, page: 1, limit: 25).returns(mock_response)
    
    response = @client.following_feed
    assert_equal mock_response, response
  end

  def test_inbox_top
    mock_response = { 'notifications' => [] }
    @client.expects(:request).with(:get, Substack::Endpoints::INBOX_TOP).returns(mock_response)
    
    response = @client.inbox_top
    assert_equal mock_response, response
  end

  def test_mark_inbox_seen
    ids = [1, 2, 3]
    mock_response = { 'success' => true }
    @client.expects(:request).with(:put, Substack::Endpoints::INBOX_SEEN, json: { ids: ids }).returns(mock_response)
    
    response = @client.mark_inbox_seen(ids)
    assert_equal mock_response, response
  end

  def test_live_streams
    mock_response = { 'streams' => [] }
    @client.expects(:request).with(:get, Substack::Endpoints::LIVE_STREAMS).returns(mock_response)
    
    response = @client.live_streams
    assert_equal mock_response, response
  end

  def test_unread_count
    mock_response = { 'count' => 5 }
    @client.expects(:request).with(:get, Substack::Endpoints::UNREAD_COUNT).returns(mock_response)
    
    response = @client.unread_count
    assert_equal mock_response, response
  end

  def test_attach_image
    image_url = 'https://example.com/image.jpg'
    mock_response = { 'id' => 'image123' }
    @client.expects(:request).with(:post, Substack::Endpoints::ATTACH_IMAGE, json: { url: image_url }).returns(mock_response)
    
    response = @client.attach_image(image_url)
    assert_equal mock_response, response
  end

  def test_post_note
    text = 'This is a test note'
    attachments = [{ 'id' => 'image123' }]
    mock_response = { 'id' => 'note123' }
    
    expected_payload = { contentMarkdown: text, attachments: attachments }
    @client.expects(:request).with(:post, Substack::Endpoints::POST_NOTE, json: expected_payload).returns(mock_response)
    
    response = @client.post_note(text: text, attachments: attachments)
    assert_equal mock_response, response
  end

  def test_react_to_note
    note_id = 'note123'
    reaction_type = 'heart'
    mock_response = { 'success' => true }
    
    note_reaction_url = Substack::Endpoints::REACT_NOTE.call(note_id)
    @client.expects(:request).with(:post, note_reaction_url, json: { type: reaction_type }).returns(mock_response)
    
    response = @client.react_to_note(note_id, reaction_type)
    assert_equal mock_response, response
  end

  def test_update_user_setting
    settings = { 'last_home_tab' => 'for-you' }
    mock_response = { 'success' => true }
    
    @client.expects(:request).with(:put, Substack::Endpoints::USER_SETTING, json: settings).returns(mock_response)
    
    response = @client.update_user_setting(settings)
    assert_equal mock_response, response
  end

  def test_publication_posts
    publication = 'example'
    limit = 10
    offset = 5
    mock_response = { 'posts' => [] }
    
    url = Substack::Endpoints::POSTS_FEED.call(publication)
    @client.expects(:request).with(:get, url, limit: limit, offset: offset).returns(mock_response)
    
    response = @client.publication_posts(publication, limit: limit, offset: offset)
    assert_equal mock_response, response
  end
end
