require_relative 'test_helper'

class ClientTest < Minitest::Test
  def setup
    # Use stub authentication methods from test_client.rb
    @client = Substack::Client.new(email: 'test@example.com', password: 'password')
  end


  def test_determine_primary_publication_url_with_custom_domain
    @client.stubs(:get_user_profile).returns({
      "primaryPublication" => {
        "custom_domain" => "example.com"
      }
    })
    
    url = @client.send(:determine_primary_publication_url)
    assert_equal "https://example.com/api/v1", url
  end

  def test_determine_primary_publication_url_with_subdomain
    @client.stubs(:get_user_profile).returns({
      "primaryPublication" => {
        "subdomain" => "example"
      }
    })
    
    url = @client.send(:determine_primary_publication_url)
    assert_equal "https://example.substack.com/api/v1", url
  end

  def test_construct_publication_url_with_custom_domain
    publication = { "custom_domain" => "example.com" }
    url = @client.send(:construct_publication_url, publication)
    assert_equal "https://example.com", url
  end

  def test_construct_publication_url_with_subdomain
    publication = { "subdomain" => "example" }
    url = @client.send(:construct_publication_url, publication)
    assert_equal "https://example.substack.com", url
  end

  def test_retry_with_backoff_success_first_try
    # The block should be called exactly once and succeed
    counter = 0
    
    result = @client.send(:retry_with_backoff) do
      counter += 1
      "success"
    end
    
    assert_equal 1, counter
    assert_equal "success", result
  end

  def test_retry_with_backoff_success_after_retries
    # The block should retry and eventually succeed
    counter = 0
    
    @client.expects(:sleep).with(1).once
    @client.expects(:sleep).with(2).once
    
    result = @client.send(:retry_with_backoff, max_retries: 3, delay: 1) do
      counter += 1
      if counter < 3
        raise RuntimeError, "Temporary failure"
      else
        "success after retries"
      end
    end
    
    assert_equal 3, counter
    assert_equal "success after retries", result
  end

  def test_retry_with_backoff_max_retries_exceeded
    # The block should fail after max retries
    counter = 0
    
    @client.expects(:sleep).with(1).once
    @client.expects(:sleep).with(2).once
    
    assert_raises(RuntimeError) do
      @client.send(:retry_with_backoff, max_retries: 3, delay: 1) do
        counter += 1
        raise RuntimeError, "Persistent failure"
      end
    end
    
    assert_equal 3, counter
  end

  def test_get_request_success
    # Mock URI and Net::HTTP
    uri = URI.parse("https://example.com/api/endpoint")
    mock_http = mock('http')
    mock_request = mock('request')
    mock_response = mock('response')
    
    # Set up expectations
    Net::HTTP.expects(:start).with(uri.host, uri.port, use_ssl: true).yields(mock_http).returns(mock_response)
    Net::HTTP::Get.expects(:new).with(uri).returns(mock_request)
    
    # Headers
    mock_request.expects(:[]=).with("User-Agent", "ruby-requests/1.0")
    mock_request.expects(:[]=).with("Accept-Encoding", "gzip, deflate")
    mock_request.expects(:[]=).with("Content-Type", "application/json")
    mock_request.expects(:[]=).with("Accept", "*/*")
    mock_request.expects(:[]=).with("Connection", "keep-alive")
    
    # Cookies
    @client.expects(:add_cookies).with(mock_request)
    
    # Response
    mock_http.expects(:request).with(mock_request).returns(mock_response)
    mock_response.expects(:code).returns("200")
    
    # Call the method
    response = @client.send(:get_request, uri, "test endpoint")
    assert_equal mock_response, response
  end

  def test_post_request_success
    # Mock URI and Net::HTTP
    uri = URI.parse("https://example.com/api/endpoint")
    mock_http = mock('http')
    mock_request = mock('request')
    mock_response = mock('response')
    
    # Request body
    body = { "key" => "value" }
    
    # Set up expectations
    Net::HTTP.expects(:start).with(uri.host, uri.port, use_ssl: true).yields(mock_http).returns(mock_response)
    Net::HTTP::Post.expects(:new).with(uri).returns(mock_request)
    
    # Headers and body
    mock_request.expects(:content_type=).with("application/json")
    mock_request.expects(:body=).with(body.to_json)
    
    # Cookies
    @client.expects(:add_cookies).with(mock_request)
    
    # Response
    mock_http.expects(:request).with(mock_request).returns(mock_response)
    
    # Call the method
    response = @client.send(:post_request, uri, body)
    assert_equal mock_response, response
  end

  def test_post_request_error
    # Mock URI
    uri = URI.parse("https://example.com/api/endpoint")
    
    # Create an error that will be raised
    error = RuntimeError.new("Network error")
    
    # Make Net::HTTP.start raise an error
    Net::HTTP.expects(:start).raises(error)
    
    # Call the method and expect it to raise
    assert_raises(RuntimeError) do
      @client.send(:post_request, uri, {})
    end
  end

  def test_handle_response_gzip_error
    # Create a mock response with invalid gzip data
    mock_response = mock('response')
    mock_response.stubs(:[]).with("content-encoding").returns("gzip")
    mock_response.stubs(:body).returns("not valid gzip data")
    mock_response.stubs(:status).returns(200)
    
    # Test that handle_response raises an error
    assert_raises(Zlib::GzipFile::Error) do
      @client.send(:handle_response, mock_response)
    end
  end

  def test_handle_response_json_parse_error
    # Create a mock response with invalid JSON data
    mock_response = mock('response')
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns("not valid json")
    mock_response.stubs(:status).returns(200)
    
    # Test that handle_response raises a JSON::ParserError
    assert_raises(JSON::ParserError) do
      @client.send(:handle_response, mock_response)
    end
  end

  def test_handle_response_with_gzip_error
    client = Substack::Client.new(email: 'test@example.com', password: 'password')
    
    # Create a mock response with invalid gzip content
    mock_response = mock('response')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns("gzip")
    mock_response.stubs(:body).returns("not valid gzip data")
    
    # Expect the gzip reader to raise an error
    Zlib::GzipReader.expects(:new).raises(Zlib::GzipFile::Error.new("not in gzip format"))
    
    # Test that the error is re-raised
    assert_raises(Zlib::GzipFile::Error) do
      client.send(:handle_response, mock_response)
    end
  end
  
  def test_handle_response_with_successful_gzip
    client = Substack::Client.new(email: 'test@example.com', password: 'password')
    
    # Create a mock response with gzipped content
    mock_response = mock('response')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns("gzip")
    
    # The original body (gzipped)
    gzipped_body = "gzipped data"
    mock_response.stubs(:body).returns(gzipped_body)
    
    # Mock the StringIO and GzipReader
    mock_io = mock('stringio')
    mock_gz = mock('gzipreader')
    
    StringIO.expects(:new).with(gzipped_body).returns(mock_io)
    Zlib::GzipReader.expects(:new).with(mock_io).returns(mock_gz)
    
    # The decompressed data
    json_data = '{"key":"value"}'
    mock_gz.expects(:read).returns(json_data)
    mock_gz.expects(:close)
    
    # Define a singleton method on the response to return the decompressed body
    mock_response.expects(:define_singleton_method).with(:body).yields.returns(json_data)
    
    # Call handle_response
    result = client.send(:handle_response, mock_response)
    
    # Verify the body was parsed
    assert_equal({"key" => "value"}, result)
  end
  
  def test_handle_response_with_json_parse_error
    client = Substack::Client.new(email: 'test@example.com', password: 'password')
    
    # Create a mock response with invalid JSON
    mock_response = mock('response')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:body).returns("This is not valid JSON")
    
    # Mock JSON.parse to raise an error
    JSON.expects(:parse).with("This is not valid JSON").raises(JSON::ParserError.new("unexpected token"))
    
    # Test that the error is re-raised
    assert_raises(JSON::ParserError) do
      client.send(:handle_response, mock_response)
    end
  end
  
  def test_determine_primary_publication_url
    client = Substack::Client.new(email: 'test@example.com', password: 'password')
    
    # Mock get_user_profile to return a profile with a primary publication
    client.expects(:get_user_profile).returns({
      "primaryPublication" => {
        "subdomain" => "testblog",
        "custom_domain" => nil
      }
    })
    
    # Call the method
    url = client.send(:determine_primary_publication_url)
    
    # Verify the correct URL was constructed
    assert_equal "https://testblog.substack.com/api/v1", url
  end
  
  def test_determine_primary_publication_url_with_custom_domain
    client = Substack::Client.new(email: 'test@example.com', password: 'password')
    
    # Mock get_user_profile to return a profile with a primary publication with custom domain
    client.expects(:get_user_profile).returns({
      "primaryPublication" => {
        "subdomain" => "testblog",
        "custom_domain" => "blog.example.com"
      }
    })
    
    # Call the method
    url = client.send(:determine_primary_publication_url)
    
    # Verify the correct URL was constructed
    assert_equal "https://blog.example.com/api/v1", url
  end
  def test_initialize
    assert_instance_of Substack::Client, @client
  end

  def test_get_user_id
    @client.stubs(:get_user_profile).returns({"id" => 123})
    user_id = @client.get_user_id
    assert_equal 123, user_id
  end

  def test_get_user_id_no_profile
    @client.stubs(:get_user_profile).returns({})
    assert_nil @client.get_user_id
  end

  def test_get_user_id_nil_profile
    @client.stubs(:get_user_profile).returns(nil)
    assert_nil @client.get_user_id
  end

  def test_post_draft
    # Stub out all the methods we'd call
    post = Substack::Post.new(title: 'Test Title', subtitle: 'Test Subtitle', user_id: 123)
    post.paragraph('This is a test paragraph.')
    
    @client.stubs(:determine_primary_publication_url).returns("https://test.substack.com/api/v1")
    @client.stubs(:request).returns({"id" => "draft123"})
    
    result = @client.post_draft(post.get_draft)
    assert_equal "draft123", result["id"]
  end
  
  def test_post_draft_with_publication
    post = Substack::Post.new(title: 'Test Title', subtitle: 'Test Subtitle', user_id: 123)
    post.paragraph('This is a test paragraph.')
    
    @client.stubs(:request).returns({"id" => "draft456"})
    
    result = @client.post_draft(post.get_draft, publication_url: "https://custom.substack.com")
    assert_equal "draft456", result["id"]
  end
  
  def test_request_get
    # Make the request method accessible for testing
    @client.instance_eval do
      def public_request(url, method: :get, json: nil, **qs)
        request(method, url, json: json, **qs)
      end
    end
    
    mock_response = mock('response')
    mock_response.stubs(:body).returns('{"success":true}')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    
    # Create a mock connection
    mock_connection = mock('connection')
    mock_connection.expects(:get).returns(mock_response)
    
    # Stub Faraday.new to return our mock connection
    Faraday.stubs(:new).returns(mock_connection)
    
    result = @client.public_request("https://test.substack.com/api/endpoint")
    assert_equal({"success" => true}, result)
  end
  
  def test_request_post
    # Make the request method accessible for testing
    @client.instance_eval do
      def public_request(url, method: :get, json: nil, **qs)
        request(method, url, json: json, **qs)
      end
    end
    
    mock_response = mock('response')
    mock_response.stubs(:body).returns('{"success":true}')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    
    # Create a mock connection that expects post with JSON
    mock_connection = mock('connection')
    mock_connection.expects(:post).returns(mock_response)
    
    # Stub Faraday.new to return our mock connection
    Faraday.stubs(:new).returns(mock_connection)
    
    result = @client.public_request("https://test.substack.com/api/endpoint", method: :post, json: {key: "value"})
    assert_equal({"success" => true}, result)
  end
  
  def test_request_with_error
    # Make the request method accessible for testing
    @client.instance_eval do
      def public_request(url, method: :get, json: nil, **qs)
        request(method, url, json: json, **qs)
      end
      
      # Override handle_response to raise a ValidationError for this test
      def handle_response(response)
        if response.status == 422
          raise Substack::ValidationError.new("Validation error", 
            status: 422, 
            errors: [{"msg" => "Invalid data"}]
          )
        else
          super
        end
      end
    end
    
    mock_response = mock('response')
    mock_response.stubs(:body).returns('{"errors":[{"msg":"Invalid data"}]}')
    mock_response.stubs(:status).returns(422)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    
    # Create a mock connection
    mock_connection = mock('connection')
    mock_connection.expects(:post).returns(mock_response)
    
    # Stub Faraday.new to return our mock connection
    Faraday.stubs(:new).returns(mock_connection)
    
    assert_raises(Substack::ValidationError) do
      @client.public_request("https://test.substack.com/api/endpoint", method: :post)
    end
  end
  
  def test_handle_response_gzip
    # Create a gzipped response
    original_content = '{"data":"test"}'
    io = StringIO.new
    gz = Zlib::GzipWriter.new(io)
    gz.write(original_content)
    gz.close
    
    gzipped_content = io.string
    
    mock_response = mock('response')
    mock_response.stubs(:[]).with("content-encoding").returns("gzip")
    mock_response.stubs(:body).returns(gzipped_content)
    mock_response.stubs(:status).returns(200)
    
    # Test the handle_response method
    result = @client.send(:handle_response, mock_response)
    assert_equal({"data" => "test"}, result)
  end
  
  def test_add_cookies
    # Setup session with cookies
    @client.instance_variable_set(:@session, {
      "substack.sid" => "test_session_id",
      "csrf-token" => "test_csrf_token"
    })
    
    # Create a mock request
    mock_request = {}
    
    # Add cookies to the request
    @client.send(:add_cookies, mock_request)
    
    # Verify cookies were added correctly
    expected_cookies = "substack.sid=test_session_id; csrf-token=test_csrf_token"
    assert_equal expected_cookies, mock_request["Cookie"]
  end
  
  def test_add_cookies_empty
    # Setup empty session
    @client.instance_variable_set(:@session, {})
    
    # Create a mock request
    mock_request = {}
    
    # Add cookies to the request
    @client.send(:add_cookies, mock_request)
    
    # Verify no Cookie header was added
    assert_nil mock_request["Cookie"]
  end
end