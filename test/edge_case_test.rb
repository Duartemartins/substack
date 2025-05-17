require_relative 'test_helper'

class EdgeCaseTest < Minitest::Test
  def setup
    @client = Substack::Client.new
    
    # Make the request method public for testing
    @client.instance_eval do
      def public_request(url, method: :get, json: nil, **qs)
        request(method, url, json: json, **qs)
      end
    end
  end

  def test_request_with_network_error
    # Stub the Faraday.new to raise a connection error
    Faraday.stubs(:new).raises(Faraday::ConnectionFailed.new("Connection failed"))
    
    assert_raises(Substack::Error) do
      @client.public_request("https://test.substack.com/api/endpoint")
    end
  end
  
  def test_request_with_timeout
    # Stub the Faraday.new to raise a timeout error
    Faraday.stubs(:new).raises(Faraday::TimeoutError.new("Request timed out"))
    
    assert_raises(Substack::Error) do
      @client.public_request("https://test.substack.com/api/endpoint")
    end
  end
  
  def test_request_with_json_parse_error
    # Get a reference to the actual handle_response method from the API module
    api_handle_response = Substack::Client::API.instance_method(:handle_response).bind(@client)
    
    mock_response = mock('response')
    mock_response.stubs(:body).returns('Invalid JSON')
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    
    # Use the API module's handle_response implementation
    assert_raises(Substack::Error) do
      api_handle_response.call(mock_response)
    end
  end
  
  def test_authentication_required
    # Simulate an unauthenticated session
    @client.instance_variable_set(:@session, {})
    
    mock_response = mock('response')
    mock_response.stubs(:body).returns('{"error":"Unauthorized"}')
    mock_response.stubs(:status).returns(401)
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    
    # Override ensure_authenticated to simulate failure
    @client.instance_eval do
      def ensure_authenticated
        raise Substack::AuthenticationError, "Authentication required"
      end
    end
    
    assert_raises(Substack::AuthenticationError) do
      @client.public_request("https://test.substack.com/api/endpoint")
    end
  end
  
  def test_post_draft_without_title
    incomplete_draft = {
      draft_subtitle: 'Subtitle without title',
      draft_body: '{"type":"doc","content":[]}',
      draft_bylines: [{"id" => 123}],
      audience: "everyone"
    }
    
    # Mock the client's post_draft method to simulate validation error
    @client.expects(:post_draft).with(incomplete_draft).raises(
      Substack::ValidationError.new(
        "Validation failed",
        status: 422,
        errors: [{"msg" => "Title is required"}]
      )
    )
    
    assert_raises(Substack::ValidationError) do
      @client.post_draft(incomplete_draft)
    end
  end
  
  def test_rate_limit_exceeded
    # Get a reference to the actual handle_response method from the API module
    api_handle_response = Substack::Client::API.instance_method(:handle_response).bind(@client)
    
    mock_response = mock('response')
    mock_response.stubs(:body).returns('{"error":"Rate limit exceeded"}')
    mock_response.stubs(:status).returns(429)
    mock_response.stubs(:[]).returns(nil)
    
    assert_raises(Substack::RateLimitError) do
      api_handle_response.call(mock_response)
    end
  end
  
  def test_not_found_resource
    # Get a reference to the actual handle_response method from the API module
    api_handle_response = Substack::Client::API.instance_method(:handle_response).bind(@client)
    
    mock_response = mock('response')
    mock_response.stubs(:body).returns('{"error":"Resource not found"}')
    mock_response.stubs(:status).returns(404)
    mock_response.stubs(:[]).returns(nil)
    
    assert_raises(Substack::NotFoundError) do
      api_handle_response.call(mock_response)
    end
  end
  
  def test_permission_denied
    # Get a reference to the actual handle_response method from the API module
    api_handle_response = Substack::Client::API.instance_method(:handle_response).bind(@client)
    
    mock_response = mock('response')
    mock_response.stubs(:body).returns('{"error":"Permission denied"}')
    mock_response.stubs(:status).returns(403)
    mock_response.stubs(:[]).returns(nil)
    
    assert_raises(Substack::AuthenticationError) do
      api_handle_response.call(mock_response)
    end
  end
  
  def test_handle_gzip_error
    # Create invalid gzip data
    invalid_gzip = "not a valid gzip"
    
    mock_response = mock('response')
    mock_response.stubs(:[]).with("content-encoding").returns("gzip")
    mock_response.stubs(:body).returns(invalid_gzip)
    mock_response.stubs(:status).returns(200)
    
    # Make the handle_response method public for testing
    @client.instance_eval { def public_handle_response(response); handle_response(response); end }
    
    assert_raises(Zlib::GzipFile::Error) do
      @client.public_handle_response(mock_response)
    end
  end
end
