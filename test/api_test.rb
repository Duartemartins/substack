require_relative 'test_helper'

# Tests for lib/substack_api/client/api.rb
class ApiTest < Minitest::Test
  def setup
    @client = Substack::Client.new(email: 'test@example.com', password: 'password')
    @client.instance_variable_set(:@session, { 'substack.sid' => 'test_sid', 'csrf-token' => 'test_csrf' })
    @client.instance_variable_set(:@logger, Logger.new(IO::NULL))
    @client.stubs(:ensure_authenticated)
    
    @mock_conn = mock('faraday_connection')
    @client.stubs(:conn).returns(@mock_conn)
    
    @temp_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry @temp_dir if @temp_dir && Dir.exist?(@temp_dir)
  end

  # ============================================
  # Feed/Stream Methods
  # ============================================
  
  def test_following_feed_default_params
    mock_response = { 'posts' => [] }
    @client.expects(:request).with(:get, Substack::Endpoints::FEED_FOLLOWING, page: 1, limit: 25).returns(mock_response)
    
    result = @client.following_feed
    assert_equal mock_response, result
  end
  
  def test_following_feed_custom_params
    mock_response = { 'posts' => [{ 'id' => 1 }] }
    @client.expects(:request).with(:get, Substack::Endpoints::FEED_FOLLOWING, page: 3, limit: 50).returns(mock_response)
    
    result = @client.following_feed(page: 3, limit: 50)
    assert_equal mock_response, result
  end
  
  def test_live_streams
    mock_response = { 'streams' => [] }
    @client.expects(:request).with(:get, Substack::Endpoints::LIVE_STREAMS).returns(mock_response)
    
    result = @client.live_streams
    assert_equal mock_response, result
  end
  
  # ============================================
  # Inbox/Notification Methods
  # ============================================
  
  def test_inbox_top
    mock_response = { 'notifications' => [] }
    @client.expects(:request).with(:get, Substack::Endpoints::INBOX_TOP).returns(mock_response)
    
    result = @client.inbox_top
    assert_equal mock_response, result
  end
  
  def test_mark_inbox_seen_with_ids
    ids = ['id1', 'id2', 'id3']
    mock_response = { 'success' => true }
    @client.expects(:request).with(:put, Substack::Endpoints::INBOX_SEEN, json: { ids: ids }).returns(mock_response)
    
    result = @client.mark_inbox_seen(ids)
    assert_equal mock_response, result
  end
  
  def test_mark_inbox_seen_empty
    mock_response = { 'success' => true }
    @client.expects(:request).with(:put, Substack::Endpoints::INBOX_SEEN, json: { ids: [] }).returns(mock_response)
    
    result = @client.mark_inbox_seen
    assert_equal mock_response, result
  end
  
  def test_unread_count
    mock_response = { 'count' => 5 }
    @client.expects(:request).with(:get, Substack::Endpoints::UNREAD_COUNT).returns(mock_response)
    
    result = @client.unread_count
    assert_equal mock_response, result
  end
  
  # ============================================
  # Image Upload/Attachment Methods
  # ============================================
  
  def test_attach_image
    image_url = 'https://example.com/image.jpg'
    mock_response = { 'id' => 'attach123' }
    @client.expects(:request).with(:post, Substack::Endpoints::ATTACH_IMAGE, json: { url: image_url }).returns(mock_response)
    
    result = @client.attach_image(image_url)
    assert_equal mock_response, result
  end
  
  def test_upload_image
    @client.unstub(:conn)
    @client.instance_variable_set(:@conn, nil)
    
    # Create a test image file
    test_image = File.join(@temp_dir, 'test.jpg')
    File.binwrite(test_image, 'fake image content')
    
    mock_response = mock('response')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:body).returns({ 'url' => 'https://uploaded.com/img.jpg' })
    
    mock_conn = mock('faraday')
    mock_conn.expects(:post).yields(mock('request').tap do |req|
      req.stubs(:headers).returns({})
      req.stubs(:body=)
    end).returns(mock_response)
    
    @client.stubs(:conn).returns(mock_conn)
    @client.stubs(:handle_response).returns({ 'url' => 'https://uploaded.com/img.jpg' })
    
    result = @client.upload_image(test_image)
    assert_equal 'https://uploaded.com/img.jpg', result['url']
  end
  
  # ============================================
  # Note Methods
  # ============================================
  
  def test_post_note_basic
    text = 'Test note'
    mock_response = { 'id' => 'note123' }
    @client.expects(:request).with(:post, Substack::Endpoints::POST_NOTE, json: { contentMarkdown: text, attachments: [] }).returns(mock_response)
    
    result = @client.post_note(text: text)
    assert_equal mock_response, result
  end
  
  def test_post_note_with_attachments
    text = 'Test note'
    attachments = [{ 'id' => 'attach1' }, { 'id' => 'attach2' }]
    mock_response = { 'id' => 'note123' }
    @client.expects(:request).with(:post, Substack::Endpoints::POST_NOTE, json: { contentMarkdown: text, attachments: attachments }).returns(mock_response)
    
    result = @client.post_note(text: text, attachments: attachments)
    assert_equal mock_response, result
  end
  
  def test_post_note_with_image
    text = 'Test with image'
    image_url = 'https://example.com/img.png'
    attachment = { 'id' => 'attach1' }
    mock_response = { 'id' => 'note123' }
    
    @client.expects(:attach_image).with(image_url).returns(attachment)
    @client.expects(:post_note).with(text: text, attachments: [attachment]).returns(mock_response)
    
    result = @client.post_note_with_image(text: text, image_url: image_url)
    assert_equal mock_response, result
  end
  
  def test_post_note_with_local_image
    text = 'Test with local image'
    image_path = '/path/to/image.jpg'
    uploaded = { 'url' => 'https://uploaded.com/img.jpg' }
    attachment = { 'id' => 'attach1' }
    mock_response = { 'id' => 'note123' }
    
    @client.expects(:upload_image).with(image_path).returns(uploaded)
    @client.expects(:attach_image).with(uploaded['url']).returns(attachment)
    @client.expects(:post_note).with(text: text, attachments: [attachment]).returns(mock_response)
    
    result = @client.post_note_with_local_image(text: text, image_path: image_path)
    assert_equal mock_response, result
  end
  
  def test_react_to_note_default_type
    note_id = 'note123'
    mock_response = { 'success' => true }
    url = Substack::Endpoints::REACT_NOTE.call(note_id)
    @client.expects(:request).with(:post, url, json: { type: 'heart' }).returns(mock_response)
    
    result = @client.react_to_note(note_id)
    assert_equal mock_response, result
  end
  
  def test_react_to_note_custom_type
    note_id = 'note123'
    mock_response = { 'success' => true }
    url = Substack::Endpoints::REACT_NOTE.call(note_id)
    @client.expects(:request).with(:post, url, json: { type: 'like' }).returns(mock_response)
    
    result = @client.react_to_note(note_id, 'like')
    assert_equal mock_response, result
  end
  
  # ============================================
  # User/Settings Methods
  # ============================================
  
  def test_update_user_setting
    settings = { 'key' => 'value' }
    mock_response = { 'success' => true }
    @client.expects(:request).with(:put, Substack::Endpoints::USER_SETTING, json: settings).returns(mock_response)
    
    result = @client.update_user_setting(settings)
    assert_equal mock_response, result
  end
  
  def test_update_user_setting_empty
    mock_response = { 'success' => true }
    @client.expects(:request).with(:put, Substack::Endpoints::USER_SETTING, json: {}).returns(mock_response)
    
    result = @client.update_user_setting
    assert_equal mock_response, result
  end
  
  # ============================================
  # Publication Methods
  # ============================================
  
  def test_publication_posts
    publication = 'testpub'
    mock_response = { 'posts' => [] }
    url = Substack::Endpoints::POSTS_FEED.call(publication)
    @client.expects(:request).with(:get, url, limit: 25, offset: 0).returns(mock_response)
    
    result = @client.publication_posts(publication)
    assert_equal mock_response, result
  end
  
  def test_publication_posts_with_params
    publication = 'testpub'
    mock_response = { 'posts' => [{ 'id' => 1 }] }
    url = Substack::Endpoints::POSTS_FEED.call(publication)
    @client.expects(:request).with(:get, url, limit: 10, offset: 20).returns(mock_response)
    
    result = @client.publication_posts(publication, limit: 10, offset: 20)
    assert_equal mock_response, result
  end
  
  # ============================================
  # Connection Tests
  # ============================================
  
  def test_conn_creates_faraday_connection
    @client.unstub(:conn)
    @client.instance_variable_set(:@conn, nil)
    
    conn = @client.send(:conn)
    
    assert_instance_of Faraday::Connection, conn
  end
  
  def test_conn_sets_cookie_header
    @client.unstub(:conn)
    @client.instance_variable_set(:@conn, nil)
    @client.instance_variable_set(:@session, { 'substack.sid' => 'my_sid', 'csrf-token' => 'my_token' })
    
    conn = @client.send(:conn)
    
    assert_includes conn.headers['Cookie'], 'substack.sid=my_sid'
    assert_includes conn.headers['Cookie'], 'csrf-token=my_token'
  end
  
  def test_conn_without_csrf_token
    @client.unstub(:conn)
    @client.instance_variable_set(:@conn, nil)
    @client.instance_variable_set(:@session, { 'substack.sid' => 'my_sid' })
    
    conn = @client.send(:conn)
    
    assert_includes conn.headers['Cookie'], 'substack.sid=my_sid'
    refute_includes conn.headers['Cookie'], 'csrf-token'
  end
  
  # ============================================
  # ensure_authenticated Tests
  # ============================================
  
  def test_ensure_authenticated_with_valid_session
    @client.unstub(:ensure_authenticated)
    @client.instance_variable_set(:@session, { 'substack.sid' => 'valid_sid' })
    
    # Should not raise
    @client.send(:ensure_authenticated)
  end
  
  def test_ensure_authenticated_raises_without_session
    @client.unstub(:ensure_authenticated)
    @client.instance_variable_set(:@session, {})
    @client.instance_variable_set(:@cookies_path, '/nonexistent/path')
    
    File.stubs(:exist?).returns(false)
    
    error = assert_raises(Substack::AuthenticationError) do
      @client.send(:ensure_authenticated)
    end
    assert_includes error.message, 'No valid session'
  end
end
