require_relative 'test_helper'

class ClientTest < Minitest::Test
  def setup
    # Use stub authentication methods from test_client.rb
    @client = Substack::Client.new(email: 'test@example.com', password: 'password')
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