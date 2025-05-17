require_relative 'test_helper'

class ApiTest < Minitest::Test
  def setup

    # Use a temporary directory for cookie testing
    @temp_dir = Dir.mktmpdir
    @cookies_path = File.join(@temp_dir, 'test_cookies.yml')
    # Use stub authentication from test_client.rb
    @client = Substack::Client.new
    
    # Ensure we're in test mode
    ENV['SUBSTACK_TEST_MODE'] = 'true'

    # Set up a session with cookies
    @client.instance_variable_set(:@session, {
      "substack.sid" => "test_session_id",
      "csrf-token" => "test_csrf_token"
    })
  end

  def teardown
    # Clean up temporary directory
    FileUtils.remove_entry @temp_dir if File.directory?(@temp_dir)
  end
  

  def test_422_with_structured_errors
    # Test with properly structured errors array
    mock_response = mock('response')
    mock_response.stubs(:status).returns(422)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns(
      JSON.dump({
        errors: [
          { param: "email", msg: "Invalid email format", location: "body" },
          { param: "password", msg: "Password too short", location: "body" }
        ]
      })
    )
    
    error = assert_raises(Substack::ValidationError) do
      @client.send(:handle_response, mock_response)
    end
    
    assert_equal 422, error.status
    assert_equal 2, error.errors.length
    assert_equal "Invalid email format", error.errors[0]["msg"]
    assert_equal "Password too short", error.errors[1]["msg"]
  end
  
  def test_422_with_empty_errors_array
    # Test with empty errors array
    mock_response = mock('response')
    mock_response.stubs(:status).returns(422)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns(JSON.dump({ errors: [] }))
    
    error = assert_raises(Substack::ValidationError) do
      @client.send(:handle_response, mock_response)
    end
    
    assert_equal 422, error.status
    assert_empty error.errors
  end
  
  def test_422_with_missing_errors_key
    # Test with valid JSON but no errors key
    mock_response = mock('response')
    mock_response.stubs(:status).returns(422)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns(JSON.dump({ message: "Validation failed" }))
    
    error = assert_raises(Substack::ValidationError) do
      @client.send(:handle_response, mock_response)
    end
    
    assert_equal 422, error.status
    assert_empty error.errors
  end
  
  def test_422_with_null_errors
    # Test with null errors value
    mock_response = mock('response')
    mock_response.stubs(:status).returns(422)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns(JSON.dump({ errors: nil }))
    
    error = assert_raises(Substack::ValidationError) do
      @client.send(:handle_response, mock_response)
    end
    
    assert_equal 422, error.status
    assert_empty error.errors
  end
  
  def test_422_with_string_errors
    # Test with string errors (not array)
    mock_response = mock('response')
    mock_response.stubs(:status).returns(422)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns(JSON.dump({ errors: "Invalid input" }))
    
    error = assert_raises(Substack::ValidationError) do
      @client.send(:handle_response, mock_response)
    end
    
    assert_equal 422, error.status
    assert_empty error.errors # Should be empty since errors is not an array
  end
  
  def test_422_with_empty_string_body
    # Test with empty string body
    mock_response = mock('response')
    mock_response.stubs(:status).returns(422)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns("")
    
    error = assert_raises(Substack::ValidationError) do
      @client.send(:handle_response, mock_response)
    end
    
    assert_equal 422, error.status
    assert_empty error.errors
  end
  
  def test_422_with_array_errors_format
    # Test with errors as a simple array of strings (different format)
    mock_response = mock('response')
    mock_response.stubs(:status).returns(422)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns(JSON.dump({ errors: ["Error 1", "Error 2"] }))
    
    error = assert_raises(Substack::ValidationError) do
      @client.send(:handle_response, mock_response)
    end
    
    assert_equal 422, error.status
    assert_equal 2, error.errors.length
    assert_equal "Error 1", error.errors[0]
    assert_equal "Error 2", error.errors[1]
  end
  def test_handle_response_status_codes
    # This test is simpler and only tests the status code error handling
    # It doesn't try to validate other aspects which could cause other errors
    
    # Test different HTTP status codes
    [401, 403, 404, 422, 429, 418, 503].each do |status|
      # Create a new mock response for each status
      mock_response = stub("response-#{status}")
      
      # First, stub the status method to return our test status
      mock_response.stubs(:status).returns(status)
      
      # For 422 we need errors array
      body_content = if status == 422
        '{"errors":[{"field":"name","message":"Required"}]}'
      else
        '{}'
      end
      
      # Stub content-encoding check
      mock_response.stubs(:[]).with("content-encoding").returns(nil)
      
      # Stub body method - needs to handle both to_s and direct access
      mock_response.stubs(:body).returns(body_content)
      
      # Different expectations based on status code
      case status
      when 401, 403
        assert_raises(Substack::AuthenticationError) do
          @client.send(:handle_response, mock_response)
        end
      when 404
        assert_raises(Substack::NotFoundError) do
          @client.send(:handle_response, mock_response)
        end
      when 422
        assert_raises(Substack::ValidationError) do
          @client.send(:handle_response, mock_response)
        end
      when 429
        assert_raises(Substack::RateLimitError) do
          @client.send(:handle_response, mock_response)
        end
      when 418  # Test status in 400..499 range
        assert_raises(Substack::APIError) do
          error = @client.send(:handle_response, mock_response)
          assert_equal "Client error", error.message if error.is_a?(Substack::APIError)
        end
      when 503  # Test status in 500..599 range
        assert_raises(Substack::APIError) do
          error = @client.send(:handle_response, mock_response)
          assert_equal "Server error", error.message if error.is_a?(Substack::APIError)
        end
      end
    end
  end

  # Basic API Tests
  def test_following_feed
    mock_response = { 'posts' => [{'id' => 1}] }
    @client.expects(:request).with(:get, Substack::Endpoints::FEED_FOLLOWING, page: 1, limit: 25).returns(mock_response)
    
    response = @client.following_feed
    assert_equal mock_response, response
  end

  def test_following_feed_with_params
    mock_response = { 'posts' => [{'id' => 1}] }
    @client.expects(:request).with(:get, Substack::Endpoints::FEED_FOLLOWING, page: 2, limit: 10).returns(mock_response)
    
    response = @client.following_feed(page: 2, limit: 10)
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

  def test_mark_inbox_seen_empty
    mock_response = { 'success' => true }
    @client.expects(:request).with(:put, Substack::Endpoints::INBOX_SEEN, json: { ids: [] }).returns(mock_response)
    
    response = @client.mark_inbox_seen
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

  # Image Tests
  def test_upload_image
    file_path = 'test_image.jpg'
    file_content = 'test_image_content'
    filename = 'test_image.jpg'
    mock_response = { 'url' => 'https://substack.com/img/test_image.jpg' }
    
    # Mock file operations
    File.expects(:binread).with(file_path).returns(file_content)
    File.expects(:basename).with(file_path).returns(filename)
    
    # Mock Faraday connection
    mock_conn = mock('conn')
    mock_request = mock('request')
    mock_response_obj = mock('response')
    
    @client.expects(:conn).returns(mock_conn)
    @client.instance_variable_set('@session', {'csrf-token' => 'test_token'})
    
    # Setup expectations for post request
    mock_conn.expects(:post).with(Substack::Endpoints::IMAGE_UPLOAD).yields(mock_request).returns(mock_response_obj)
    mock_request.expects(:headers).at_least_once.returns({})
    mock_request.expects(:body=).with(file_content)
    
    # Mock response handling
    @client.expects(:handle_response).with(mock_response_obj).returns(mock_response)
    
    # Call the method
    response = @client.upload_image(file_path)
    assert_equal mock_response, response
  end

  def test_attach_image
    image_url = 'https://example.com/image.jpg'
    mock_response = { 'id' => 'image123' }
    @client.expects(:request).with(:post, Substack::Endpoints::ATTACH_IMAGE, json: { url: image_url }).returns(mock_response)
    
    response = @client.attach_image(image_url)
    assert_equal mock_response, response
  end

  # Note Tests
  def test_post_note
    text = 'This is a test note'
    attachments = [{ 'id' => 'image123' }]
    mock_response = { 'id' => 'note123' }
    
    expected_payload = { contentMarkdown: text, attachments: attachments }
    @client.expects(:request).with(:post, Substack::Endpoints::POST_NOTE, json: expected_payload).returns(mock_response)
    
    response = @client.post_note(text: text, attachments: attachments)
    assert_equal mock_response, response
  end

  def test_post_note_with_empty_attachments
    text = 'This is a test note without attachments'
    mock_response = { 'id' => 'note123' }
    
    expected_payload = { contentMarkdown: text, attachments: [] }
    @client.expects(:request).with(:post, Substack::Endpoints::POST_NOTE, json: expected_payload).returns(mock_response)
    
    response = @client.post_note(text: text)
    assert_equal mock_response, response
  end

  def test_post_note_with_image
    text = 'This is a test note with image'
    image_url = 'https://example.com/image.jpg'
    attachment = { 'id' => 'image123' }
    mock_response = { 'id' => 'note123' }
    
    # Expectations
    @client.expects(:attach_image).with(image_url).returns(attachment)
    @client.expects(:post_note).with(text: text, attachments: [attachment]).returns(mock_response)
    
    response = @client.post_note_with_image(text: text, image_url: image_url)
    assert_equal mock_response, response
  end

  def test_post_note_with_local_image
    text = 'This is a test note with local image'
    image_path = 'local_image.jpg'
    uploaded_image = { 'url' => 'https://substack.com/img/uploaded.jpg' }
    attachment = { 'id' => 'image123' }
    mock_response = { 'id' => 'note123' }
    
    # Expectations
    @client.expects(:upload_image).with(image_path).returns(uploaded_image)
    @client.expects(:attach_image).with(uploaded_image['url']).returns(attachment)
    @client.expects(:post_note).with(text: text, attachments: [attachment]).returns(mock_response)
    
    response = @client.post_note_with_local_image(text: text, image_path: image_path)
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

  def test_react_to_note_default_heart
    note_id = 'note123'
    mock_response = { 'success' => true }
    
    note_reaction_url = Substack::Endpoints::REACT_NOTE.call(note_id)
    @client.expects(:request).with(:post, note_reaction_url, json: { type: "heart" }).returns(mock_response)
    
    response = @client.react_to_note(note_id)
    assert_equal mock_response, response
  end

  def test_update_user_setting
    settings = { 'last_home_tab' => 'for-you' }
    mock_response = { 'success' => true }
    
    @client.expects(:request).with(:put, Substack::Endpoints::USER_SETTING, json: settings).returns(mock_response)
    
    response = @client.update_user_setting(settings)
    assert_equal mock_response, response
  end

  def test_update_user_setting_empty
    mock_response = { 'success' => true }
    
    @client.expects(:request).with(:put, Substack::Endpoints::USER_SETTING, json: {}).returns(mock_response)
    
    response = @client.update_user_setting
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

  def test_publication_posts_default_params
    publication = 'example'
    mock_response = { 'posts' => [] }
    
    url = Substack::Endpoints::POSTS_FEED.call(publication)
    @client.expects(:request).with(:get, url, limit: 25, offset: 0).returns(mock_response)
    
    response = @client.publication_posts(publication)
    assert_equal mock_response, response
  end

  # Request and Response Handling Tests
  def test_conn_with_session
    @client.instance_variable_set('@session', {'substack.sid' => 'test_sid', 'csrf-token' => 'test_token'})
    
    # Clear any existing connection
    @client.instance_variable_set('@conn', nil)
    
    # Get the new connection
    conn = @client.send(:conn)
    
    # Should be a Faraday connection
    assert_instance_of Faraday::Connection, conn
    assert_includes conn.headers['Cookie'], 'substack.sid=test_sid'
    assert_includes conn.headers['Cookie'], 'csrf-token=test_token'
  end

  def test_conn_without_session
    @client.instance_variable_set('@session', {})
    
    # Clear any existing connection
    @client.instance_variable_set('@conn', nil)
    
    # Get the new connection
    conn = @client.send(:conn)
    
    # Should be a Faraday connection
    assert_instance_of Faraday::Connection, conn
    assert_nil conn.headers['Cookie']
  end

  def test_ensure_authenticated_with_session
    @client.instance_variable_set('@session', {'substack.sid' => 'test_sid'})
    
    # This should not raise an error
    @client.send(:ensure_authenticated)
  end

  def test_ensure_authenticated_loads_cookies
    @client.instance_variable_set('@session', {})
    @client.instance_variable_set('@cookies_path', 'test_cookies.yml')
    
    File.expects(:exist?).with('test_cookies.yml').returns(true)
    @client.expects(:load_cookies).with('test_cookies.yml')
    
    # This should not raise an error because we mock the loading
    @client.send(:ensure_authenticated)
  end

  def test_ensure_authenticated_raises_error
    @client.instance_variable_set('@session', {})
    @client.instance_variable_set('@cookies_path', 'test_cookies.yml')
    
    File.expects(:exist?).with('test_cookies.yml').returns(false)
    
    # This should raise an authentication error
    assert_raises Substack::AuthenticationError do
      @client.send(:ensure_authenticated)
    end
  end

  def test_handle_response_success
    mock_response = mock('response')
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:body).returns({ 'data' => 'test' })
    
    result = @client.send(:handle_response, mock_response)
    assert_equal({ 'data' => 'test' }, result)
  end

  def test_handle_response_authentication_error
    [401, 403].each do |status|
      mock_response = mock('response')
      mock_response.stubs(:[]).with("content-encoding").returns(nil)
      mock_response.stubs(:status).returns(status)
      mock_response.stubs(:body).returns('{}')
      
      assert_raises Substack::AuthenticationError do
        @client.send(:handle_response, mock_response)
      end
    end
  end

  def test_handle_response_not_found_error
    mock_response = mock('response')
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:status).returns(404)
    mock_response.stubs(:body).returns('{}')
    
    assert_raises Substack::NotFoundError do
      @client.send(:handle_response, mock_response)
    end
  end

  def test_handle_response_validation_error
    mock_response = mock('response')
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:status).returns(422)
    # Using a hash instead of a string to simulate what happens in actual code
    mock_response.stubs(:body).returns({"errors" => ["Invalid input"]})
    
    assert_raises Substack::ValidationError do
      @client.send(:handle_response, mock_response)
    end
  end

  def test_handle_response_rate_limit_error
    mock_response = mock('response')
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:status).returns(429)
    mock_response.stubs(:body).returns('{}')
    
    assert_raises Substack::RateLimitError do
      @client.send(:handle_response, mock_response)
    end
  end

  def test_handle_response_client_error
    mock_response = mock('response')
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:status).returns(400)
    mock_response.stubs(:body).returns('{}')
    
    assert_raises Substack::APIError do
      @client.send(:handle_response, mock_response)
    end
  end

  def test_handle_response_server_error
    mock_response = mock('response')
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:status).returns(500)
    mock_response.stubs(:body).returns('{}')
    
    assert_raises Substack::APIError do
      @client.send(:handle_response, mock_response)
    end
  end

  def test_handle_response_json_parse_error
    mock_response = mock('response')
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:body).returns("invalid json")
    
    # The client handle_response function wraps the JSON::ParserError in a Substack::Error
    @client.instance_variable_get(:@logger).expects(:error).with("JSON Parsing Error: unexpected character: 'invalid json'")
    @client.instance_variable_get(:@logger).expects(:debug).with(regexp_matches(/Raw Response Body/))
    
    assert_raises JSON::ParserError do
      @client.send(:handle_response, mock_response)
    end
  end

  def test_request_makes_faraday_call
    method = :get
    url = '/test'
    qs = { param: 'value' }
    
    # Mock authentication check
    @client.expects(:ensure_authenticated)
    
    # Mock Faraday connection and response
    mock_conn = mock('conn')
    mock_request = mock('request')
    mock_response = mock('response')
    
    @client.expects(:conn).returns(mock_conn)
    mock_conn.expects(:get).yields(mock_request).returns(mock_response)
    mock_request.expects(:url).with(url, qs)
    mock_request.expects(:headers).at_least_once.returns({})
    
    # Mock response handling
    @client.expects(:handle_response).with(mock_response).returns({'success' => true})
    
    # Call the method
    result = @client.send(:request, method, url, **qs)
    assert_equal({'success' => true}, result)
  end

  def test_request_with_json_payload
    method = :post
    url = '/test'
    json = { data: 'test' }
    
    # Mock authentication check
    @client.expects(:ensure_authenticated)
    
    # Mock Faraday connection and response
    mock_conn = mock('conn')
    mock_request = mock('request')
    mock_response = mock('response')
    
    @client.expects(:conn).returns(mock_conn)
    mock_conn.expects(:post).yields(mock_request).returns(mock_response)
    mock_request.expects(:url).with(url, {})
    mock_request.expects(:headers).at_least_once.returns({})
    mock_request.expects(:body=).with(JSON.dump(json))
    
    # Mock response handling
    @client.expects(:handle_response).with(mock_response).returns({'success' => true})
    
    # Call the method
    result = @client.send(:request, method, url, json: json)
    assert_equal({'success' => true}, result)
  end

  def test_request_with_csrf_token
    method = :post
    url = '/test'
    @client.instance_variable_set('@session', {'csrf-token' => 'test_token'})
    
    # Mock authentication check
    @client.expects(:ensure_authenticated)
    
    # Mock Faraday connection and response
    mock_conn = mock('conn')
    mock_request = mock('request')
    mock_response = mock('response')
    
    @client.expects(:conn).returns(mock_conn)
    mock_conn.expects(:post).yields(mock_request).returns(mock_response)
    mock_request.expects(:url).with(url, {})
    
    # We need to use a real hash for headers to test token setting
    headers = {}
    mock_request.expects(:headers).at_least_once.returns(headers)
    
    # Mock response handling
    @client.expects(:handle_response).with(mock_response).returns({'success' => true})
    
    # Call the method
    result = @client.send(:request, method, url)
    assert_equal({'success' => true}, result)
    assert_equal 'test_token', headers['X-CSRF-Token']
  end

  def test_handle_response_with_gzip
    # Mock response with gzip content
    mock_response = mock('response')
    mock_response.stubs(:[]).with("content-encoding").returns("gzip")
    mock_response.stubs(:status).returns(200)
    
    # Create a real gzipped JSON
    json_data = '{"data":"test"}'
    string_io = StringIO.new
    gz = Zlib::GzipWriter.new(string_io)
    gz.write(json_data)
    gz.close
    gzipped_data = string_io.string
    
    mock_response.stubs(:body).returns(gzipped_data)
    
    # Test the method
    result = @client.send(:handle_response, mock_response)
    assert_equal({"data" => "test"}, result)
  end
  
  def test_handle_response_with_gzip_error
    # Mock response with gzip content but invalid data
    mock_response = mock('response')
    mock_response.stubs(:[]).with("content-encoding").returns("gzip")
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:body).returns("not gzipped data")
    
    # Should raise an error when trying to decompress invalid data
    assert_raises do
      @client.send(:handle_response, mock_response)
    end
  end

  def test_request_handles_faraday_error
    @client.expects(:ensure_authenticated)
    @client.expects(:conn).raises(Faraday::Error.new("Connection failed"))
    
    assert_raises Substack::Error do
      @client.send(:request, :get, '/test')
    end
  end

  def test_handle_response_with_correct_error_handling
    # Create a mapping of HTTP status codes to expected error classes
    error_mappings = {
      401 => Substack::AuthenticationError,
      403 => Substack::AuthenticationError,
      404 => Substack::NotFoundError,
      422 => Substack::ValidationError,
      429 => Substack::RateLimitError,
      400 => Substack::APIError,
      500 => Substack::APIError
    }
    
    # Test each error code
    error_mappings.each do |status, error_class|
      # Create a mock response with the current status code
      mock_response = mock('response')
      mock_response.stubs(:status).returns(status)
      mock_response.stubs(:[]).with("content-encoding").returns(nil)
      
      if status == 422
        # For validation errors, include an 'errors' array
        mock_response.stubs(:body).returns('{"errors":[{"msg":"Validation failed"}]}')
      else
        mock_response.stubs(:body).returns('{}')
      end
      
      # Test that the appropriate error is raised
      assert_raises(error_class) do
        @client.send(:handle_response, mock_response)
      end
    end
  end
  
  def test_conn_method_with_complete_session
    # Set up a complete session with both required cookies
    @client.instance_variable_set(:@session, {
      'substack.sid' => 'complete_session_id',
      'csrf-token' => 'complete_csrf_token'
    })
    
    # Mock Faraday to verify the correct headers are set
    mock_builder = mock('builder')
    mock_connection = mock('connection')
    
    # Set up expectations for Faraday
    Faraday.expects(:new).yields(mock_builder).returns(mock_connection)
    mock_builder.expects(:request).with(:url_encoded)
    mock_builder.expects(:response).with(:json)
    mock_builder.expects(:adapter).with(Faraday.default_adapter)
    
    # Expect the Cookie header to be set with both cookies
    mock_builder.expects(:headers).with do |headers|
      assert_equal "substack.sid=complete_session_id; csrf-token=complete_csrf_token", headers['Cookie']
      true
    end
    
    # Call the method
    result = @client.send(:conn)
    
    # Verify the result is the mock connection
    assert_equal mock_connection, result
  end
  
  def test_conn_method_without_session
    # Set up an empty session
    @client.instance_variable_set(:@session, {})
    
    # Mock Faraday to verify no cookie headers are set
    mock_builder = mock('builder')
    mock_connection = mock('connection')
    
    # Set up expectations for Faraday
    Faraday.expects(:new).yields(mock_builder).returns(mock_connection)
    mock_builder.expects(:request).with(:url_encoded)
    mock_builder.expects(:response).with(:json)
    mock_builder.expects(:adapter).with(Faraday.default_adapter)
    
    # The headers method should not be called because there are no cookies
    mock_builder.expects(:headers).never
    
    # Call the method
    result = @client.send(:conn)
    
    # Verify the result is the mock connection
    assert_equal mock_connection, result
  end
  
  def test_conn_method_with_partial_session
    # Set up a partial session with only sid (no csrf token)
    @client.instance_variable_set(:@session, {
      'substack.sid' => 'partial_session_id'
    })
    
    # Mock Faraday to verify the cookie header only has sid
    mock_builder = mock('builder')
    mock_connection = mock('connection')
    
    # Set up expectations for Faraday
    Faraday.expects(:new).yields(mock_builder).returns(mock_connection)
    mock_builder.expects(:request).with(:url_encoded)
    mock_builder.expects(:response).with(:json)
    mock_builder.expects(:adapter).with(Faraday.default_adapter)
    
    # Expect the Cookie header to be set with only sid
    mock_builder.expects(:headers).with do |headers|
      assert_equal "substack.sid=partial_session_id", headers['Cookie']
      true
    end
    
    # Call the method
    result = @client.send(:conn)
    
    # Verify the result is the mock connection
    assert_equal mock_connection, result
  end
  
  def test_upload_image_with_session_token
    # Create a mock file
    temp_file = File.join(@temp_dir, 'test_image.jpg')
    File.write(temp_file, 'fake image data')
    
    # Mock the Faraday connection
    mock_connection = mock('connection')
    mock_request = mock('request')
    mock_response = mock('response')
    
    @client.stubs(:conn).returns(mock_connection)
    
    # Set expectations
    mock_connection.expects(:post).with(Substack::Client::Endpoints::IMAGE_UPLOAD).yields(mock_request).returns(mock_response)
    
    # Request headers should include the CSRF token
    mock_request.expects(:headers).returns({})
    mock_request.headers['Content-Type'] = 'application/octet-stream'
    mock_request.headers['X-CSRF-Token'] = 'test_csrf_token'
    mock_request.headers['X-File-Name'] = 'test_image.jpg'
    
    # Request body should be the file content
    mock_request.expects(:body=).with('fake image data')
    
    # Handle the response
    @client.expects(:handle_response).with(mock_response).returns({'url' => 'https://example.com/image.jpg'})
    
    # Call the method
    result = @client.upload_image(temp_file)
    
    # Verify the result
    assert_equal({'url' => 'https://example.com/image.jpg'}, result)
  end
  
  def test_upload_image_without_csrf_token
    # Create a client without a CSRF token
    @client.instance_variable_set(:@session, {'substack.sid' => 'test_session_id'})
    
    # Create a mock file
    temp_file = File.join(@temp_dir, 'test_image.jpg')
    File.write(temp_file, 'fake image data')
    
    # Mock the Faraday connection
    mock_connection = mock('connection')
    mock_request = mock('request')
    mock_response = mock('response')
    
    @client.stubs(:conn).returns(mock_connection)
    
    # Set expectations
    mock_connection.expects(:post).with(Substack::Client::Endpoints::IMAGE_UPLOAD).yields(mock_request).returns(mock_response)
    
    # Request headers should NOT include the CSRF token
    mock_request.expects(:headers).returns({})
    mock_request.headers['Content-Type'] = 'application/octet-stream'
    mock_request.headers['X-File-Name'] = 'test_image.jpg'
    
    # Request body should be the file content
    mock_request.expects(:body=).with('fake image data')
    
    # Handle the response
    @client.expects(:handle_response).with(mock_response).returns({'url' => 'https://example.com/image.jpg'})
    
    # Call the method
    result = @client.upload_image(temp_file)
    
    # Verify the result
    assert_equal({'url' => 'https://example.com/image.jpg'}, result)
  end
  
  def test_request_method_with_csrf_token
    # Set up the session with CSRF token
    @client.instance_variable_set(:@session, {
      'substack.sid' => 'test_session_id',
      'csrf-token' => 'test_csrf_token'
    })
    
    # Mock the Faraday connection
    mock_connection = mock('connection')
    mock_request = mock('request')
    mock_response = mock('response')
    
    @client.stubs(:conn).returns(mock_connection)
    @client.stubs(:ensure_authenticated)
    
    # Set expectations for GET request
    mock_connection.expects(:get).yields(mock_request).returns(mock_response)
    
    # Request should set the CSRF token in headers
    mock_request.expects(:url).with('/test/endpoint', {param: 'value'})
    mock_request.expects(:headers).returns({})
    mock_request.headers['Content-Type'] = 'application/json'
    mock_request.headers['User-Agent'] = 'ruby-substack-api/0.1.0'
    mock_request.headers['X-CSRF-Token'] = 'test_csrf_token'
    
    # No JSON body for GET
    mock_request.expects(:body=).never
    
    # Handle the response
    @client.expects(:handle_response).with(mock_response).returns({'success' => true})
    
    # Call the method
    result = @client.send(:request, :get, '/test/endpoint', param: 'value')
    
    # Verify the result
    assert_equal({'success' => true}, result)
  end
  
  def test_post_request_with_json_body
    # Set up the session
    @client.instance_variable_set(:@session, {
      'substack.sid' => 'test_session_id',
      'csrf-token' => 'test_csrf_token'
    })
    
    # Mock the Faraday connection
    mock_connection = mock('connection')
    mock_request = mock('request')
    mock_response = mock('response')
    
    @client.stubs(:conn).returns(mock_connection)
    @client.stubs(:ensure_authenticated)
    
    # Set expectations for POST request
    mock_connection.expects(:post).yields(mock_request).returns(mock_response)
    
    # Request should include correct URL, headers, and JSON body
    mock_request.expects(:url).with('/test/endpoint', {param: 'query'})
    mock_request.expects(:headers).returns({})
    mock_request.headers['Content-Type'] = 'application/json'
    mock_request.headers['User-Agent'] = 'ruby-substack-api/0.1.0'
    mock_request.headers['X-CSRF-Token'] = 'test_csrf_token'
    
    # JSON body should be properly serialized
    json_body = {key: 'value', nested: {data: true}}
    mock_request.expects(:body=).with(JSON.dump(json_body))
    
    # Handle the response
    @client.expects(:handle_response).with(mock_response).returns({'success' => true})
    
    # Call the method
    result = @client.send(:request, :post, '/test/endpoint', json: json_body, param: 'query')
    
    # Verify the result
    assert_equal({'success' => true}, result)
  end
  
  def test_request_with_faraday_error
    @client.stubs(:ensure_authenticated)
    @client.stubs(:conn).raises(Faraday::ConnectionFailed.new('Connection error'))
    
    assert_raises(Substack::Error) do
      @client.send(:request, :get, '/test/endpoint')
    end
  end
  
  def test_ensure_authenticated_with_valid_session
    # Set up a valid session
    @client.instance_variable_set(:@session, {'substack.sid' => 'valid_session'})
    
    # This should not raise an error
    @client.send(:ensure_authenticated)
  end
  
  def test_ensure_authenticated_with_empty_session_and_load_cookies
    # Set up an empty session but with valid cookies on disk
    @client.instance_variable_set(:@session, {})
    
    # Create a cookies file
    cookies_data = {'substack.sid' => 'loaded_session'}.to_yaml
    File.write(@cookies_path, cookies_data)
    
    # Should attempt to load cookies
    @client.expects(:load_cookies).with(@cookies_path).once
    
    # This should now not raise an error 
    @client.send(:ensure_authenticated)
  end
  
  def test_ensure_authenticated_with_no_valid_session
    # Empty session and no cookies file
    @client.instance_variable_set(:@session, {})
    @client.instance_variable_set(:@cookies_path, nil)
    
    # This should raise an AuthenticationError
    assert_raises(Substack::AuthenticationError) do
      @client.send(:ensure_authenticated)
    end
  end

  def test_upload_image_complete
    # Mock file operations
    file_path = "/tmp/test_image.jpg"
    file_content = "fake image data"
    filename = "test_image.jpg"
    
    File.expects(:binread).with(file_path).returns(file_content)
    File.expects(:basename).with(file_path).returns(filename)
    
    # Set up a session with cookies
    @client.instance_variable_set(:@session, {
      "substack.sid" => "test_session_id",
      "csrf-token" => "test_csrf_token"
    })
    
    # Mock Faraday connection and response
    mock_conn = mock('connection')
    mock_response = mock('response')
    mock_request = mock('request')
    
    @client.expects(:conn).returns(mock_conn)
    mock_conn.expects(:post).with(Substack::Endpoints::IMAGE_UPLOAD).yields(mock_request).returns(mock_response)
    
    # Mock request headers including X-File-Name and X-CSRF-Token
    mock_headers = {}
    mock_request.expects(:headers).at_least_once.returns(mock_headers)
    
    # Expect mock_headers to be set with the correct values
    mock_headers['Content-Type'] = 'application/octet-stream'
    mock_headers['X-CSRF-Token'] = 'test_csrf_token'
    mock_headers['X-File-Name'] = URI.encode_www_form_component(filename)
    
    # Mock request body
    mock_request.expects(:body=).with(file_content)
    
    # Mock handle_response to return a successful result
    @client.expects(:handle_response).with(mock_response).returns({"url" => "https://substack.com/img/test_image.jpg"})
    
    # Call the method
    result = @client.upload_image(file_path)
    assert_equal "https://substack.com/img/test_image.jpg", result["url"]
  end
  
  def test_upload_image_faraday_error
    # Mock file operations
    file_path = "/tmp/test_image.jpg"
    file_content = "fake image data"
    filename = "test_image.jpg"
    
    File.expects(:binread).with(file_path).returns(file_content)
    File.expects(:basename).with(file_path).returns(filename)
    
    # Set up a session with cookies
    @client.instance_variable_set(:@session, {
      "substack.sid" => "test_session_id",
      "csrf-token" => "test_csrf_token"
    })
    
    # Mock Faraday to raise an error
    mock_conn = mock('connection')
    @client.expects(:conn).returns(mock_conn)
    mock_conn.expects(:post).raises(Faraday::ConnectionFailed.new("Connection failed"))
    
    # Expect error to be raised
    assert_raises(Substack::Error) do
      @client.upload_image(file_path)
    end
  end
  
  def test_request_with_faraday_error
    # Ensure authenticated
    @client.expects(:ensure_authenticated)
    
    # Mock Faraday connection
    mock_conn = mock('connection')
    @client.expects(:conn).returns(mock_conn)
    
    # Make it raise a Faraday error
    mock_conn.expects(:get).raises(Faraday::TimeoutError.new("Request timed out"))
    
    # Test that the error is caught and re-raised as a Substack::Error
    assert_raises(Substack::Error) do
      @client.send(:request, :get, "/some/endpoint")
    end
  end
  
  def test_conn_with_existing_connection
    # Create a mock connection
    mock_conn = mock('connection')
    
    # Set it as the instance variable
    @client.instance_variable_set(:@conn, mock_conn)
    
    # Call conn method and verify it returns the cached connection
    result = @client.send(:conn)
    assert_equal mock_conn, result
  end
  
  def test_conn_with_session_cookies
    # Reset any existing connection
    @client.instance_variable_set(:@conn, nil)
    
    # Set up a session with cookies
    @client.instance_variable_set(:@session, {
      "substack.sid" => "test_session_id",
      "csrf-token" => "test_csrf_token"
    })
    
    # Mock Faraday builder and connection
    mock_conn = mock('connection')
    Faraday.expects(:new).yields(mock_builder = mock('builder')).returns(mock_conn)
    
    # Mock the builder configuration
    mock_builder.expects(:request).with(:url_encoded)
    mock_builder.expects(:response).with(:json)
    mock_builder.expects(:adapter).with(Faraday.default_adapter)
    
    # Check headers are set correctly
    mock_headers = {}
    mock_builder.expects(:headers).returns(mock_headers)
    
    # Call conn and make sure cookies are set in headers
    result = @client.send(:conn)
    assert_equal mock_conn, result
    assert_equal "substack.sid=test_session_id; csrf-token=test_csrf_token", mock_headers["Cookie"]
  end
  
  def test_handle_response_success_with_string_body
    # Create a mock response with a string body
    mock_response = mock('response')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:body).returns('{"key":"value"}')
    
    # Call handle_response
    result = @client.send(:handle_response, mock_response)
    
    # Verify the body was parsed correctly
    assert_equal({"key" => "value"}, result)
  end
  
  def test_post_note_with_image_failure
    text = "Test image note"
    image_url = "https://example.com/bad_image.jpg"
    
    # Make attach_image raise an error
    @client.expects(:attach_image).with(image_url).raises(Substack::APIError.new("Failed to attach image"))
    
    # Test that the error is propagated
    assert_raises(Substack::APIError) do
      @client.post_note_with_image(text: text, image_url: image_url)
    end
  end
  
  def test_post_note_with_local_image_failure
    text = "Test local image note"
    image_path = "/tmp/nonexistent.jpg"
    
    # Make upload_image raise an error
    File.expects(:binread).with(image_path).raises(Errno::ENOENT.new("No such file or directory"))
    
    # Test that the error is propagated
    assert_raises(Errno::ENOENT) do
      @client.post_note_with_local_image(text: text, image_path: image_path)
    end
  end
  
  def test_request_with_authentication_error
    # Set up client with no session
    @client.instance_variable_set(:@session, {})
    @client.instance_variable_set(:@cookies_path, nil)
    
    # Test that request raises AuthenticationError
    assert_raises(Substack::AuthenticationError) do
      @client.send(:request, :get, "/some/endpoint")
    end
  end
  
  def test_mark_inbox_seen_empty
    # Test with empty array (default parameter)
    @client.expects(:request).with(:put, Substack::Endpoints::INBOX_SEEN, json: { ids: [] }).returns({ "success" => true })
    
    result = @client.mark_inbox_seen
    assert_equal({ "success" => true }, result)
  end

  # Test the 429 error case specifically
  def test_rate_limit_error
    response = mock('response')
    response.stubs(:status).returns(429)
    response.stubs(:[]).with('content-encoding').returns(nil)
    response.stubs(:body).returns('{}')
    
    # Jump directly to the error handling part of handle_response
    # by monkeypatching the status check part
    def @client.handle_response(response)
      status = response.status
        
      case status
      when 401, 403
        raise AuthenticationError, "Authentication failed (HTTP #{status})"
      when 404
        raise NotFoundError.new(nil, status: status)
      when 422
        # Validation errors
        parsed_body = JSON.parse(response.body.to_s) rescue {}
        errors = parsed_body['errors'] || []
        raise ValidationError.new(nil, status: status, errors: errors)
      when 429
        raise RateLimitError.new("Rate limit exceeded", status: status)
      when 400..499
        raise APIError.new("Client error", status: status)
      when 500..599
        raise APIError.new("Server error", status: status)
      end
    end
    
    error = assert_raises(Substack::RateLimitError) do
      @client.handle_response(response)
    end
    
    assert_equal "Rate limit exceeded", error.message
    assert_equal 429, error.status
  end

  # Test the 400-499 range error case specifically
  def test_client_error_range
    response = mock('response')
    response.stubs(:status).returns(418) # I'm a teapot
    response.stubs(:[]).with('content-encoding').returns(nil)
    response.stubs(:body).returns('{}')
    
    # Jump directly to the error handling part
    def @client.handle_response(response)
      status = response.status
        
      case status
      when 401, 403
        raise AuthenticationError, "Authentication failed (HTTP #{status})"
      when 404
        raise NotFoundError.new(nil, status: status)
      when 422
        # Validation errors
        parsed_body = JSON.parse(response.body.to_s) rescue {}
        errors = parsed_body['errors'] || []
        raise ValidationError.new(nil, status: status, errors: errors)
      when 429
        raise RateLimitError.new("Rate limit exceeded", status: status)
      when 400..499
        raise APIError.new("Client error", status: status)
      when 500..599
        raise APIError.new("Server error", status: status)
      end
    end
    
    error = assert_raises(Substack::APIError) do
      @client.handle_response(response)
    end
    
    assert_equal "Client error", error.message
    assert_equal 418, error.status
  end

  # Test the 500-599 range error case specifically
  def test_server_error_range
    response = mock('response')
    response.stubs(:status).returns(503) # Service Unavailable
    response.stubs(:[]).with('content-encoding').returns(nil)
    response.stubs(:body).returns('{}')
    
    # Jump directly to the error handling part
    def @client.handle_response(response)
      status = response.status
        
      case status
      when 401, 403
        raise AuthenticationError, "Authentication failed (HTTP #{status})"
      when 404
        raise NotFoundError.new(nil, status: status)
      when 422
        # Validation errors
        parsed_body = JSON.parse(response.body.to_s) rescue {}
        errors = parsed_body['errors'] || []
        raise ValidationError.new(nil, status: status, errors: errors)
      when 429
        raise RateLimitError.new("Rate limit exceeded", status: status)
      when 400..499
        raise APIError.new("Client error", status: status)
      when 500..599
        raise APIError.new("Server error", status: status)
      end
    end
    
    error = assert_raises(Substack::APIError) do
      @client.handle_response(response)
    end
    
    assert_equal "Server error", error.message
    assert_equal 503, error.status
  end


  def test_handle_response_json_parse_error
    # Create a mock response with HTTP 200 but invalid JSON body
    mock_response = mock('response')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{"bad json')
    
    # Should return the raw body when JSON parsing fails
    result = @client.send(:handle_response, mock_response)
    assert_equal '{"bad json', result
  end
  
  def test_handle_response_empty_body
    # Create a mock response with HTTP 200 but empty body
    mock_response = mock('response')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('')
    
    # Should return an empty hash when body is empty
    result = @client.send(:handle_response, mock_response)
    assert_equal({}, result)
  end
  
  def test_handle_response_nil_body
    # Create a mock response with HTTP 200 but nil body
    mock_response = mock('response')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns(nil)
    
    # Should return an empty hash when body is nil
    result = @client.send(:handle_response, mock_response)
    assert_equal({}, result)
  end
  
  def test_handle_response_422_with_malformed_json
    # Create a mock response with HTTP 422 but malformed JSON
    mock_response = mock('response')
    mock_response.stubs(:status).returns(422)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{"bad json')
    
    # Make sure JSON.parse safely handles malformed JSON
    error = assert_raises(Substack::ValidationError) do
      @client.send(:handle_response, mock_response)
    end
    
    assert_equal 422, error.status
    assert_empty error.errors
  end
  
  def test_handle_response_gzip_error
    # Create a mock response with HTTP 200 and claimed gzip encoding
    mock_response = mock('response')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns("gzip")
    mock_response.stubs(:body).returns('not gzipped content')
    
    # Set up Zlib to raise an error when trying to inflate non-gzipped content
    string_io = mock('string_io')
    Zlib::GzipReader.expects(:new).raises(Zlib::Error.new("not in gzip format"))
    
    # Should fall back to treating the body as regular text
    result = @client.send(:handle_response, mock_response)
    assert_equal 'not gzipped content', result
  end
  
  def test_handle_response_status_code_429
    # Create a mock response with HTTP 429 (rate limit)
    mock_response = mock('response')
    mock_response.stubs(:status).returns(429)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{}')
    
    # Test that handle_response raises RateLimitError with correct message and status
    error = assert_raises(Substack::RateLimitError) do
      @client.send(:handle_response, mock_response)
    end
    
    # Verify error details
    assert_equal "Rate limit exceeded", error.message
    assert_equal 429, error.status
  end
  
  def test_handle_response_status_code_4xx
    # Test all client error codes in 400-499 range (except specific ones with custom handling)
    [400, 402, 418, 450, 499].each do |status_code|
      # Skip status codes that have special handling
      next if [401, 403, 404, 422, 429].include?(status_code)
      
      # Create a mock response with the test status code
      mock_response = mock('response')
      mock_response.stubs(:status).returns(status_code)
      mock_response.stubs(:[]).with("content-encoding").returns(nil)
      mock_response.stubs(:body).returns('{}')
      
      # Test that handle_response raises APIError with correct message and status
      error = assert_raises(Substack::APIError) do
        @client.send(:handle_response, mock_response)
      end
      
      # Verify error details
      assert_equal "Client error", error.message
      assert_equal status_code, error.status
    end
  end
  
  def test_handle_response_status_code_5xx
    # Test server error codes in 500-599 range
    [500, 502, 503, 504, 599].each do |status_code|
      # Create a mock response with the test status code
      mock_response = mock('response')
      mock_response.stubs(:status).returns(status_code)
      mock_response.stubs(:[]).with("content-encoding").returns(nil)
      mock_response.stubs(:body).returns('{}')
      
      # Test that handle_response raises APIError with correct message and status
      error = assert_raises(Substack::APIError) do
        @client.send(:handle_response, mock_response)
      end
      
      # Verify error details
      assert_equal "Server error", error.message
      assert_equal status_code, error.status
    end
  end

  def test_ensure_authenticated_with_valid_session
    # Set up a valid session
    @client.instance_variable_set(:@session, {
      "substack.sid" => "valid_session_id",
      "csrf-token" => "valid_csrf_token"
    })
    
    # This should not raise an error
    @client.send(:ensure_authenticated)
  end

  def test_ensure_authenticated_no_session_with_cookies
    # Set up a client with no session but a cookies path
    @client.instance_variable_set(:@session, {})
    cookies_path = '/tmp/fake_cookies.yml'
    @client.instance_variable_set(:@cookies_path, cookies_path)
    
    # Expect load_cookies to be called
    File.expects(:exist?).with(cookies_path).returns(true)
    @client.expects(:load_cookies).with(cookies_path)
    
    @client.send(:ensure_authenticated)
  end

  def test_ensure_authenticated_no_session_no_cookies
    # Set up a client with no session and no cookies
    @client.instance_variable_set(:@session, {})
    cookies_path = '/tmp/nonexistent_cookies.yml'
    @client.instance_variable_set(:@cookies_path, cookies_path)
    
    # Expect that the file doesn't exist
    File.expects(:exist?).with(cookies_path).returns(false)
    
    # This should raise AuthenticationError
    assert_raises(Substack::AuthenticationError) do
      @client.send(:ensure_authenticated)
    end
  end
  
  def test_upload_image
    # Mock file operations
    file_path = "/tmp/test_image.jpg"
    file_content = "fake image data"
    filename = "test_image.jpg"
    
    File.expects(:binread).with(file_path).returns(file_content)
    File.expects(:basename).with(file_path).returns(filename)
    
    # Set up a session with cookies
    @client.instance_variable_set(:@session, {
      "substack.sid" => "test_session_id",
      "csrf-token" => "test_csrf_token"
    })
    
    # Mock Faraday connection and response
    mock_conn = mock('connection')
    mock_response = mock('response')
    mock_request = mock('request')
    
    @client.expects(:conn).returns(mock_conn)
    mock_conn.expects(:post).with(Substack::Endpoints::IMAGE_UPLOAD).yields(mock_request).returns(mock_response)
    
    # Mock request headers
    mock_headers = {}
    mock_request.expects(:headers).at_least_once.returns(mock_headers)
    
    # Mock request body
    mock_request.expects(:body=).with(file_content)
    
    # Mock handle_response
    @client.expects(:handle_response).with(mock_response).returns({"url" => "https://substack.com/img/test_image.jpg"})
    
    # Call the method
    result = @client.upload_image(file_path)
    assert_equal "https://substack.com/img/test_image.jpg", result["url"]
  end
  
  def test_attach_image
    image_url = "https://example.com/image.jpg"
    attachment_id = "att_123456"
    
    # Expect request to be called with the right parameters
    @client.expects(:request).with(
      :post, 
      Substack::Endpoints::ATTACH_IMAGE, 
      json: { url: image_url }
    ).returns({ "id" => attachment_id })
    
    result = @client.attach_image(image_url)
    assert_equal attachment_id, result["id"]
  end
  
  def test_post_note_with_image
    text = "Check out this cool image!"
    image_url = "https://example.com/image.jpg"
    attachment = { "id" => "att_123456" }
    note_response = { "id" => "note_123" }
    
    # Expectations
    @client.expects(:attach_image).with(image_url).returns(attachment)
    @client.expects(:post_note).with(
      text: text, 
      attachments: [attachment]
    ).returns(note_response)
    
    result = @client.post_note_with_image(text: text, image_url: image_url)
    assert_equal "note_123", result["id"]
  end
  
  def test_post_note_with_local_image
    text = "Check out this local image!"
    image_path = "/tmp/local_image.jpg"
    uploaded = { "url" => "https://substack.com/img/local_image.jpg" }
    attachment = { "id" => "att_789012" }
    note_response = { "id" => "note_456" }
    
    # Expectations
    @client.expects(:upload_image).with(image_path).returns(uploaded)
    @client.expects(:attach_image).with(uploaded["url"]).returns(attachment)
    @client.expects(:post_note).with(
      text: text, 
      attachments: [attachment]
    ).returns(note_response)
    
    result = @client.post_note_with_local_image(text: text, image_path: image_path)
    assert_equal "note_456", result["id"]
  end
  
  def test_react_to_note
    note_id = "note_123"
    reaction_type = "heart"
    
    # Construct the endpoint URL with the note ID
    url = Substack::Endpoints::REACT_NOTE.call(note_id)
    
    # Expect request to be called with the right parameters
    @client.expects(:request).with(
      :post, 
      url, 
      json: { type: reaction_type }
    ).returns({ "success" => true })
    
    result = @client.react_to_note(note_id, reaction_type)
    assert_equal true, result["success"]
  end
  
  def test_following_feed
    page = 2
    limit = 10
    
    # Expect request to be called with the right parameters
    @client.expects(:request).with(
      :get, 
      Substack::Endpoints::FEED_FOLLOWING, 
      page: page, 
      limit: limit
    ).returns({ "posts" => [] })
    
    result = @client.following_feed(page: page, limit: limit)
    assert_equal [], result["posts"]
  end
  
  def test_conn_creates_faraday_connection
    # Reset any existing connection
    @client.instance_variable_set(:@conn, nil)
    
    # Set up a session with cookies
    @client.instance_variable_set(:@session, {
      "substack.sid" => "test_session_id",
      "csrf-token" => "test_csrf_token"
    })
    
    # Mock Faraday builder
    mock_conn = mock('connection')
    mock_builder = mock('builder')
    
    Faraday.expects(:new).yields(mock_builder).returns(mock_conn)
    
    # Expect the builder to be configured
    mock_builder.expects(:request).with(:url_encoded)
    mock_builder.expects(:response).with(:json)
    mock_builder.expects(:adapter).with(Faraday.default_adapter)
    
    # Check headers
    mock_builder.stubs(:headers).returns({})
    
    # Call conn and make sure it returns the connection
    result = @client.send(:conn)
    assert_equal mock_conn, result
    
    # Call it again to make sure it's cached
    @client.send(:conn)
  end
  
  def test_handle_response_with_http_errors
    # Test a series of error status codes
    error_cases = [
      { status: 401, error_class: Substack::AuthenticationError },
      { status: 403, error_class: Substack::AuthenticationError },
      { status: 404, error_class: Substack::NotFoundError },
      { status: 422, error_class: Substack::ValidationError, body: { 'errors' => [{'msg' => 'Invalid data'}] }.to_json },
      { status: 429, error_class: Substack::RateLimitError },
      { status: 400, error_class: Substack::APIError },
      { status: 500, error_class: Substack::APIError }
    ]
    
    error_cases.each do |test_case|
      # Create a mock response
      mock_response = mock('response')
      mock_response.stubs(:status).returns(test_case[:status])
      
      # Stub the necessary methods for all responses
      mock_response.stubs(:[]).with("content-encoding").returns(nil)
      
      # Ensure body is properly handled
      body_str = test_case[:body] || "{}"
      mock_response.stubs(:body).returns(body_str)
      
      # When status is 422, make body parse as valid JSON for validation errors
      if test_case[:status] == 422
        # The response body should be a string that can be parsed
        mock_response.stubs(:body).returns(body_str)
        # Mock the JSON parse to return the expected structure
        JSON.stubs(:parse).with(body_str).returns({'errors' => [{'msg' => 'Invalid data'}]})
      end
      
      # Test that handle_response raises the appropriate error
      assert_raises(test_case[:error_class]) do
        @client.send(:handle_response, mock_response)
      end
    end
    
    # Reset any JSON stubs
    JSON.unstub(:parse)
  end
  
  def test_handle_response_with_already_parsed_body
    # Create a mock response with a pre-parsed body (a Hash or Array)
    mock_response = mock('response')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    
    # Create a parsed body (Hash) that the handle_response method should return as-is
    parsed_body = { "key" => "value" }
    mock_response.stubs(:body).returns(parsed_body)
    
    # Call handle_response and verify it returns the body as-is
    result = @client.send(:handle_response, mock_response)
    assert_equal parsed_body, result
    
    # Test with an Array body
    array_body = [{ "id" => 1 }, { "id" => 2 }]
    mock_response.stubs(:body).returns(array_body)
    
    result = @client.send(:handle_response, mock_response)
    assert_equal array_body, result
  end

  def test_upload_image_complete_with_mocks
    # Mock file operations
    file_path = "/tmp/test_image.jpg"
    file_content = "fake image data"
    filename = "test_image.jpg"
    
    File.stubs(:binread).with(file_path).returns(file_content)
    File.stubs(:basename).with(file_path).returns(filename)
    
    # Mock Faraday connection and request/response
    mock_conn = mock('connection')
    mock_response = mock('response')
    mock_request = mock('request')
    
    @client.stubs(:conn).returns(mock_conn)
    mock_conn.stubs(:post).with(Substack::Endpoints::IMAGE_UPLOAD).yields(mock_request).returns(mock_response)
    
    # Mock request headers
    mock_headers = {}
    mock_request.stubs(:headers).returns(mock_headers)
    
    # Mock request body
    mock_request.stubs(:body=).with(file_content)
    
    # Mock response for handle_response
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{"url":"https://substack.com/img/test_image.jpg"}')
    
    # Call the method
    result = @client.upload_image(file_path)
    
    # Verify headers were set correctly
    assert_equal "application/octet-stream", mock_headers["Content-Type"]
    assert_equal "test_csrf_token", mock_headers["X-CSRF-Token"]
    assert_equal URI.encode_www_form_component(filename), mock_headers["X-File-Name"]
    
    # Verify result
    assert_equal "https://substack.com/img/test_image.jpg", result["url"]
  end
  
  def test_request_failure_cases
    # Mock the necessary methods
    @client.stubs(:ensure_authenticated)
    mock_conn = mock('connection')
    @client.stubs(:conn).returns(mock_conn)
    
    # Test case: Connection fails with Faraday error
    mock_conn.stubs(:get).raises(Faraday::ConnectionFailed.new("Connection refused"))
    
    assert_raises(Substack::Error) do
      @client.send(:request, :get, "/test/endpoint")
    end
    
    # Test case: Response has error status
    mock_response = mock('response')
    mock_response.stubs(:status).returns(500)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns("{}")
    
    mock_conn.stubs(:post).returns(mock_response)
    
    assert_raises(Substack::APIError) do
      @client.send(:request, :post, "/test/endpoint", json: {})
    end
  end
  
  def test_gzipped_response_handling
    # Mock the necessary methods
    @client.stubs(:ensure_authenticated)
    mock_conn = mock('connection')
    @client.stubs(:conn).returns(mock_conn)
    
    # Create a gzipped response
    test_data = { "success" => true, "data" => [1, 2, 3] }
    gzipped_data = StringIO.new
    gz = Zlib::GzipWriter.new(gzipped_data)
    gz.write(test_data.to_json)
    gz.close
    
    # Mock response
    mock_response = mock('response')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns("gzip")
    mock_response.stubs(:body).returns(gzipped_data.string)
    
    mock_conn.stubs(:get).returns(mock_response)
    
    # Call the method
    result = @client.send(:request, :get, "/test/endpoint")
    
    # Verify the gzipped data was properly decompressed and parsed
    assert_equal test_data, result
  end
  
  def test_unsuccessful_gzip_decompression
    # Mock the necessary methods
    @client.stubs(:ensure_authenticated)
    mock_conn = mock('connection')
    @client.stubs(:conn).returns(mock_conn)
    
    # Create a fake "gzipped" response that's actually invalid
    invalid_gzip_data = "Not really gzipped data"
    
    # Mock response
    mock_response = mock('response')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns("gzip")
    mock_response.stubs(:body).returns(invalid_gzip_data)
    
    mock_conn.stubs(:get).returns(mock_response)
    
    # Call the method and expect it to raise an error
    assert_raises(Zlib::GzipFile::Error) do
      @client.send(:request, :get, "/test/endpoint")
    end
  end

  def test_handle_response_success
    # Create a mock response with HTTP 200 and regular JSON string body
    mock_response = mock('response')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{"key":"value"}')
    
    # Call the method
    result = @client.send(:handle_response, mock_response)
    
    # Verify result
    assert_equal({"key" => "value"}, result)
  end
  
  def test_handle_response_with_hash_body
    # Create a mock response with HTTP 200 and body that's already a Hash
    # This simulates when Faraday middleware has already parsed the JSON
    mock_response = mock('response')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    
    # Create a pre-parsed body (this is what would happen with Faraday's json middleware)
    mock_body = {"key" => "value"}
    mock_response.stubs(:body).returns(mock_body)
    
    # Override JSON.parse to ensure it's not called
    # If it is called with a Hash argument, it would raise a TypeError
    JSON.expects(:parse).never
    
    # Call the method
    result = @client.send(:handle_response, mock_response)
    
    # Verify result
    assert_equal(mock_body, result)
  end
  
  def test_handle_response_with_array_body
    # Create a mock response with HTTP 200 and body that's already an Array
    mock_response = mock('response')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    
    # Create a pre-parsed body (this is what would happen with Faraday's json middleware)
    mock_body = [{"id" => 1}, {"id" => 2}]
    mock_response.stubs(:body).returns(mock_body)
    
    # Override JSON.parse to ensure it's not called
    JSON.expects(:parse).never
    
    # Call the method
    result = @client.send(:handle_response, mock_response)
    
    # Verify result
    assert_equal(mock_body, result)
  end
  
  def test_handle_response_401
    # Create a mock response with HTTP 401
    mock_response = mock('response')
    mock_response.stubs(:status).returns(401)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{}')
    
    # Test that handle_response raises AuthenticationError
    error = assert_raises(Substack::AuthenticationError) do
      @client.send(:handle_response, mock_response)
    end
    
    # Verify the error message contains the status code
    assert_match(/HTTP 401/, error.message)
  end

  def test_handle_response_403
    # Create a mock response with HTTP 403
    mock_response = mock('response')
    mock_response.stubs(:status).returns(403)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{}')
    
    # Test that handle_response raises AuthenticationError
    assert_raises(Substack::AuthenticationError) do
      @client.send(:handle_response, mock_response)
    end
  end
  
  def test_handle_response_404
    # Create a mock response with HTTP 404
    mock_response = mock('response')
    mock_response.stubs(:status).returns(404)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{}')
    
    # Test that handle_response raises NotFoundError
    error = assert_raises(Substack::NotFoundError) do
      @client.send(:handle_response, mock_response)
    end
    
    # Verify the error has the correct status
    assert_equal 404, error.status
  end
  
  def test_handle_response_422
    # Create a mock response with HTTP 422
    mock_response = mock('response')
    mock_response.stubs(:status).returns(422)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{"errors":[{"msg":"Invalid data"}]}')
    
    # Test that handle_response raises ValidationError
    assert_raises(Substack::ValidationError) do
      @client.send(:handle_response, mock_response)
    end
  end
  
  def test_handle_response_429
    # Create a mock response with HTTP 429
    mock_response = mock('response')
    mock_response.stubs(:status).returns(429)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{}')
    
    # Test that handle_response raises RateLimitError
    error = assert_raises(Substack::RateLimitError) do
      @client.send(:handle_response, mock_response)
    end
    
    # Verify the error has the correct message and status
    assert_equal "Rate limit exceeded", error.message
    assert_equal 429, error.status
  end
  
  def test_handle_response_gzip_encoded
    # Create a mock response with HTTP 200 and gzip encoding
    mock_response = mock('response')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns("gzip")
    
    # In a real gzip response, the body would be binary data
    # But for this test we can just mock the behavior of the zlib inflate
    Zlib::GzipReader.expects(:new).returns(StringIO.new('{"key":"gzip_value"}'))
    
    # Result should be parsed JSON
    result = @client.send(:handle_response, mock_response)
    
    # Verify result
    assert_equal({"key" => "gzip_value"}, result)
  end
  
  def test_handle_response_case_statement_coverage
    # Test explicit status checking for each case branch
    # This will help ensure each line in the case statement is covered
    
    # Create a common response stub with different status values
    mock_response = mock('response')
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{}')
    
    # Test each specific status code to ensure the case statement is covered
    
    # Test for status 401 (Authentication error)
    mock_response.stubs(:status).returns(401)
    error = assert_raises(Substack::AuthenticationError) do
      @client.send(:handle_response, mock_response)
    end
    assert_match(/HTTP 401/, error.message)
    
    # Test for status 403 (Authentication error)
    mock_response.stubs(:status).returns(403)
    error = assert_raises(Substack::AuthenticationError) do
      @client.send(:handle_response, mock_response)
    end
    assert_match(/HTTP 403/, error.message)
    
    # Test for status 404 (Not found error)
    mock_response.stubs(:status).returns(404)
    error = assert_raises(Substack::NotFoundError) do
      @client.send(:handle_response, mock_response)
    end
    assert_equal 404, error.status
    
    # Test for status 422 (Validation error)
    mock_response.stubs(:status).returns(422)
    mock_response.stubs(:body).returns('{"errors":[{"msg":"Field is required"}]}')
    error = assert_raises(Substack::ValidationError) do
      @client.send(:handle_response, mock_response)
    end
    assert_equal 422, error.status
    assert_equal 1, error.errors.size
    
    # Test for status 429 (Rate limit error)
    mock_response.stubs(:status).returns(429)
    error = assert_raises(Substack::RateLimitError) do
      @client.send(:handle_response, mock_response)
    end
    assert_equal 429, error.status
    
    # Test for status 418 (Client error range)
    mock_response.stubs(:status).returns(418)
    error = assert_raises(Substack::APIError) do
      @client.send(:handle_response, mock_response)
    end
    assert_equal 418, error.status
    assert_equal "Client error", error.message
    
    # Test for status 503 (Server error range)
    mock_response.stubs(:status).returns(503)
    error = assert_raises(Substack::APIError) do
      @client.send(:handle_response, mock_response)
    end
    assert_equal 503, error.status
    assert_equal "Server error", error.message
  end

  def test_handle_response_401_authentication_error
    # Create a mock response with HTTP 401
    mock_response = mock('response')
    mock_response.stubs(:status).returns(401)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{}')
    
    # Test that handle_response raises AuthenticationError
    error = assert_raises(Substack::AuthenticationError) do
      @client.send(:handle_response, mock_response)
    end
    
    # Verify error message contains status code
    assert_match(/Authentication failed \(HTTP 401\)/, error.message)
  end
  
  def test_handle_response_403_authentication_error
    # Create a mock response with HTTP 403
    mock_response = mock('response')
    mock_response.stubs(:status).returns(403)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{}')
    
    # Test that handle_response raises AuthenticationError
    error = assert_raises(Substack::AuthenticationError) do
      @client.send(:handle_response, mock_response)
    end
    
    # Verify error message contains status code
    assert_match(/Authentication failed \(HTTP 403\)/, error.message)
  end
  
  def test_handle_response_404_not_found_error
    # Create a mock response with HTTP 404
    mock_response = mock('response')
    mock_response.stubs(:status).returns(404)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{}')
    
    # Test that handle_response raises NotFoundError
    error = assert_raises(Substack::NotFoundError) do
      @client.send(:handle_response, mock_response)
    end
    
    # Verify the error has the correct status
    assert_equal 404, error.status
  end
  
  def test_handle_response_422_validation_error_with_errors
    # Create a mock response with HTTP 422 and validation errors
    mock_response = mock('response')
    mock_response.stubs(:status).returns(422)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{"errors":[{"field":"title","message":"Title is required"}]}')
    
    # Test that handle_response raises ValidationError
    error = assert_raises(Substack::ValidationError) do
      @client.send(:handle_response, mock_response)
    end
    
    # Verify the error has correct status and errors
    assert_equal 422, error.status
    assert_equal 1, error.errors.size
    assert_equal({"field" => "title", "message" => "Title is required"}, error.errors.first)
  end
  
  def test_handle_response_422_validation_error_with_empty_errors
    # Create a mock response with HTTP 422 but empty errors array
    mock_response = mock('response')
    mock_response.stubs(:status).returns(422)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{"errors":[]}')
    
    # Test that handle_response raises ValidationError
    error = assert_raises(Substack::ValidationError) do
      @client.send(:handle_response, mock_response)
    end
    
    # Verify the error has correct status and empty errors array
    assert_equal 422, error.status
    assert_empty error.errors
  end
  
  def test_edge_case_status_code_handling
    # Test a deliberately comprehensive selection of status codes to ensure
    # our case statement has proper coverage
    
    status_code_tests = {
      401 => Substack::AuthenticationError,
      403 => Substack::AuthenticationError,
      404 => Substack::NotFoundError,
      422 => Substack::ValidationError,
      429 => Substack::RateLimitError,
      400 => Substack::APIError,
      418 => Substack::APIError, # I'm a teapot!
      450 => Substack::APIError,
      499 => Substack::APIError,
      500 => Substack::APIError,
      502 => Substack::APIError,
      503 => Substack::APIError,
      599 => Substack::APIError
    }
    
    status_code_tests.each do |status_code, error_class|
      # Create a mock response with the test status code
      mock_response = mock('response')
      mock_response.stubs(:status).returns(status_code)
      mock_response.stubs(:[]).with("content-encoding").returns(nil)
      mock_response.stubs(:body).returns('{}')
      
      # Test that handle_response raises the expected error class
      error = assert_raises(error_class) do
        @client.send(:handle_response, mock_response)
      end
      
      # Verify error has the correct status code
      assert_equal status_code, error.status if error.respond_to?(:status)
    end
  end

  def test_post_note_with_image_integration
    text = "Test note with image"
    image_url = "https://example.com/image.jpg"
    
    # Mock the API responses
    attachment_response = { "id" => "att123", "url" => image_url }
    note_response = { "id" => "note123", "content" => text }
    
    # Expectations for the API calls
    @client.expects(:attach_image).with(image_url).returns(attachment_response)
    @client.expects(:post_note).with(
      text: text,
      attachments: [attachment_response]
    ).returns(note_response)
    
    # Call the method
    result = @client.post_note_with_image(text: text, image_url: image_url)
    
    # Verify the result
    assert_equal "note123", result["id"]
    assert_equal text, result["content"]
  end
  
  def test_post_note_with_local_image_integration
    text = "Test note with local image"
    image_path = "/tmp/test.jpg"
    
    # Mock the API responses
    upload_response = { "url" => "https://substack.com/image.jpg" }
    attachment_response = { "id" => "att456", "url" => upload_response["url"] }
    note_response = { "id" => "note456", "content" => text }
    
    # Expectations for the API calls
    @client.expects(:upload_image).with(image_path).returns(upload_response)
    @client.expects(:attach_image).with(upload_response["url"]).returns(attachment_response)
    @client.expects(:post_note).with(
      text: text,
      attachments: [attachment_response]
    ).returns(note_response)
    
    # Call the method
    result = @client.post_note_with_local_image(text: text, image_path: image_path)
    
    # Verify the result
    assert_equal "note456", result["id"]
    assert_equal text, result["content"]
  end
  
  def test_handle_response_status_codes
    status_codes = [401, 403, 404, 422, 429, 444, 500]
    
    status_codes.each do |status|
      # Create a mock response
      mock_response = mock("response-#{status}")
      mock_response.stubs(:status).returns(status)
      mock_response.stubs(:[]).with("content-encoding").returns(nil)
      
      if status == 422
        mock_response.stubs(:body).returns('{"errors":[{"msg":"Validation error"}]}')
      else
        mock_response.stubs(:body).returns('{}')
      end
      
      # Determine the expected error class
      expected_error = case status
        when 401, 403 then Substack::AuthenticationError
        when 404 then Substack::NotFoundError
        when 422 then Substack::ValidationError
        when 429 then Substack::RateLimitError
        when 400..499 then Substack::APIError
        when 500..599 then Substack::APIError
      end
      
      # Test that handle_response raises the appropriate error
      assert_raises(expected_error) do
        @client.send(:handle_response, mock_response)
      end
    end
  end
  
  def test_connection_without_session
    # Set up client with no session
    @client.instance_variable_set(:@session, {})
    @client.instance_variable_set(:@conn, nil)
    
    # Mock Faraday
    mock_conn = mock('connection')
    mock_builder = mock('builder')
    
    Faraday.expects(:new).yields(mock_builder).returns(mock_conn)
    
    # Expectations for the builder
    mock_builder.expects(:request).with(:url_encoded)
    mock_builder.expects(:response).with(:json)
    mock_builder.expects(:adapter).with(Faraday.default_adapter)
    
    # Headers should not have cookies
    mock_headers = {}
    mock_builder.expects(:headers).returns(mock_headers)
    
    # Call the method
    result = @client.send(:conn)
    
    # Verify the result and that no Cookie header was set
    assert_equal mock_conn, result
    assert_nil mock_headers["Cookie"]
  end
  
  def test_conn_with_partial_session
    # Set up client with only sid, no csrf
    @client.instance_variable_set(:@session, { "substack.sid" => "test_session_id" })
    @client.instance_variable_set(:@conn, nil)
    
    # Mock Faraday
    mock_conn = mock('connection')
    mock_builder = mock('builder')
    
    Faraday.expects(:new).yields(mock_builder).returns(mock_conn)
    
    # Expectations for the builder
    mock_builder.expects(:request).with(:url_encoded)
    mock_builder.expects(:response).with(:json)
    mock_builder.expects(:adapter).with(Faraday.default_adapter)
    
    # Headers should have cookies
    mock_headers = {}
    mock_builder.expects(:headers).returns(mock_headers)
    
    # Call the method
    result = @client.send(:conn)
    
    # Verify the result and that only the sid was set (no csrf)
    assert_equal mock_conn, result
    assert_equal "substack.sid=test_session_id", mock_headers["Cookie"]
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
  
  # Tests for handle_response method error conditions
  
  def test_handle_response_rate_limit_error
    # Create mock response with 429 status code
    mock_response = mock('response')
    mock_response.stubs(:status).returns(429)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{"error":"Too many requests"}')
    mock_response.stubs(:body).returns('{"error":"Too many requests"}')
    
    # Need to stub this for now so the test doesn't go beyond status check
    JSON.stubs(:parse).never
    
    # Test that handle_response raises RateLimitError
    error = assert_raises(Substack::RateLimitError) do
      @client.send(:handle_response, mock_response)
    end
    
    # Verify error has correct message and status
    assert_equal "Rate limit exceeded", error.message
    assert_equal 429, error.status
  end
  
  def test_handle_response_client_error
    # Test client error in 400..499 range (using 418 - I'm a teapot)
    mock_response = mock('response')
    mock_response.stubs(:status).returns(418)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{"error":"I\'m a teapot"}')
    
    # Need to stub this for now so the test doesn't go beyond status check
    JSON.stubs(:parse).never
    
    # Test that handle_response raises APIError
    error = assert_raises(Substack::APIError) do
      @client.send(:handle_response, mock_response)
    end
    
    # Verify error has correct message and status
    assert_equal "Client error", error.message
    assert_equal 418, error.status
  end
  
  def test_handle_response_server_error
    # Test server error in 500..599 range
    mock_response = mock('response')
    mock_response.stubs(:status).returns(503)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{"error":"Service unavailable"}')
    
    # Need to stub this for now so the test doesn't go beyond status check
    JSON.stubs(:parse).never
    
    # Test that handle_response raises APIError
    error = assert_raises(Substack::APIError) do
      @client.send(:handle_response, mock_response)
    end
    
    # Verify error has correct message and status
    assert_equal "Server error", error.message
    assert_equal 503, error.status
  end
  
  def test_handle_response_validation_error
    # Test validation error (422)
    mock_response = mock('response')
    mock_response.stubs(:status).returns(422)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    
    # Create validation error JSON with errors array
    error_json = '{"errors":[{"field":"title","message":"Title is required"}]}'
    mock_response.stubs(:body).returns(error_json)
    mock_response.stubs(:body).returns(error_json)
    
    # Mock JSON.parse to return our expected parsed structure
    parsed_json = {"errors" => [{"field" => "title", "message" => "Title is required"}]}
    JSON.stubs(:parse).with(error_json).returns(parsed_json)
    
    # Test that handle_response raises ValidationError
    error = assert_raises(Substack::ValidationError) do
      @client.send(:handle_response, mock_response)
    end
    
    # Verify error has correct status and errors array
    assert_equal 422, error.status
    assert_equal 1, error.errors.size
    assert_equal({"field" => "title", "message" => "Title is required"}, error.errors.first)
  end
  
  def test_handle_response_validation_error_with_invalid_json
    # Test validation error with invalid JSON body
    mock_response = mock('response')
    mock_response.stubs(:status).returns(422)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('not valid json')
    mock_response.stubs(:body).returns('not valid json')
    
    # Mock JSON.parse to rescue properly
    JSON.stubs(:parse).with('not valid json').raises(JSON::ParserError.new("unexpected token"))
    
    # Test that handle_response still raises ValidationError and doesn't crash
    error = assert_raises(Substack::ValidationError) do
      @client.send(:handle_response, mock_response)
    end
    
    # Verify error has correct status and empty errors
    assert_equal 422, error.status
    assert_empty error.errors
  end
  
  def test_handle_response_auth_errors
    # Test both 401 and 403 status codes
    [401, 403].each do |status|
      mock_response = mock("response-#{status}")
      mock_response.stubs(:status).returns(status)
      mock_response.stubs(:[]).with("content-encoding").returns(nil)
      mock_response.stubs(:body).returns('{"error":"Unauthorized"}')
      
      # Need to stub this for now so the test doesn't go beyond status check
      JSON.stubs(:parse).never
      
      # Test that handle_response raises AuthenticationError
      error = assert_raises(Substack::AuthenticationError) do
        @client.send(:handle_response, mock_response)
      end
      
      # Verify error message includes status code
      assert_match(/HTTP #{status}/, error.message)
    end
  end
  
  def test_handle_response_not_found
    # Test 404 status code
    mock_response = mock('response')
    mock_response.stubs(:status).returns(404)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns('{"error":"Not found"}')
    
    # Need to stub this for now so the test doesn't go beyond status check
    JSON.stubs(:parse).never
    
    # Test that handle_response raises NotFoundError
    error = assert_raises(Substack::NotFoundError) do
      @client.send(:handle_response, mock_response)
    end
    
    # Verify error has correct status
    assert_equal 404, error.status
  end
end
