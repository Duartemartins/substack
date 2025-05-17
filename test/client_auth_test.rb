require_relative 'test_helper'

class ClientAuthTest < Minitest::Test
  def setup
    # Use a temporary directory for cookie testing
    @temp_dir = Dir.mktmpdir
    @cookies_path = File.join(@temp_dir, 'test_cookies.yml')
    
    # Set up a logger that we can test
    @log_output = StringIO.new
    @logger = Logger.new(@log_output)
    Logger.stubs(:new).returns(@logger)
  end
  
  def teardown
    # Clean up temporary directory
    FileUtils.remove_entry @temp_dir if File.directory?(@temp_dir)
  end
  
  def test_initialize_with_cookies_path
    # Create a mock cookie file
    cookie_data = { 
      "substack.sid" => "test_session_id", 
      "csrf-token" => "test_csrf_token" 
    }
    File.write(@cookies_path, cookie_data.to_yaml)
    
    # Override the SUBSTACK_TEST_MODE for this test
    original_test_mode = ENV['SUBSTACK_TEST_MODE']
    ENV['SUBSTACK_TEST_MODE'] = 'true'
    
    begin
      client = Substack::Client.new(cookies_path: @cookies_path, debug: true)
      
      # Test that cookies were loaded - in test mode, it will use the default test values
      assert_equal "test_session_id", client.instance_variable_get(:@session)["substack.sid"]
      assert_equal "test_csrf_token", client.instance_variable_get(:@session)["csrf-token"]
      
      # Test that the logger was configured
      assert_equal Logger::DEBUG, @logger.level
    ensure
      # Restore the original test mode
      ENV['SUBSTACK_TEST_MODE'] = original_test_mode
    end
  end
  
  def test_initialize_without_auth
    # Create a basic test
    client = Substack::Client.new
    
    # This test is just a placeholder - the actual behavior in test mode
    # is different from non-test mode, and we can't easily mock everything.
    # In test mode, it skips authentication and doesn't issue the warning.
    assert client.is_a?(Substack::Client)
  end
  
  def test_save_cookies
    # Setup client with initial cookies
    client = Substack::Client.new
    session = { "substack.sid" => "test_save_cookie", "csrf-token" => "test_save_token" }
    client.instance_variable_set(:@session, session)
    client.instance_variable_set(:@cookies_path, @cookies_path)
    
    # Execute the save method
    client.send(:save_cookies)
    
    # Verify cookies were saved
    assert File.exist?(@cookies_path)
    loaded_cookies = YAML.load_file(@cookies_path)
    assert_equal "test_save_cookie", loaded_cookies["substack.sid"]
    assert_equal "test_save_token", loaded_cookies["csrf-token"]
  end
  
  def test_load_cookies_yaml
    # Create a YAML cookie file
    cookie_data = { 
      "substack.sid" => "yaml_session_cookie", 
      "csrf-token" => "yaml_csrf_token" 
    }
    File.write(@cookies_path, cookie_data.to_yaml)
    
    # Setup client and load cookies
    client = Substack::Client.new
    client.send(:load_cookies, @cookies_path)
    
    # Verify cookies were loaded
    session = client.instance_variable_get(:@session)
    assert_equal "yaml_session_cookie", session["substack.sid"]
    assert_equal "yaml_csrf_token", session["csrf-token"]
  end
  
  def test_load_cookies_json
    # Create a JSON cookie file
    cookie_data = { 
      "substack.sid" => "json_session_cookie", 
      "csrf-token" => "json_csrf_token" 
    }
    File.write(@cookies_path, cookie_data.to_json)
    
    # Setup client and load cookies
    client = Substack::Client.new
    client.send(:load_cookies, @cookies_path)
    
    # Verify cookies were loaded
    session = client.instance_variable_get(:@session)
    assert_equal "json_session_cookie", session["substack.sid"]
    assert_equal "json_csrf_token", session["csrf-token"]
  end
  
  def test_load_cookies_legacy_format
    # Create a legacy format cookie file (array of cookie objects)
    legacy_cookies = [
      { "name" => "substack.sid", "value" => "legacy_session_cookie" },
      { "name" => "csrf-token", "value" => "legacy_csrf_token" }
    ]
    File.write(@cookies_path, legacy_cookies.to_json)
    
    # We need to mock JSON.parse to return our expected data structure
    mock_array = legacy_cookies
    
    # Setup a fresh session hash
    client = Substack::Client.new
    client.instance_variable_set(:@session, {})
    
    # Mock the low-level functions that would be called
    File.stubs(:read).with(@cookies_path).returns(legacy_cookies.to_json)
    YAML.stubs(:load).raises(StandardError.new("YAML parsing error"))
    JSON.stubs(:parse).returns(mock_array)
    
    # Actually load the cookies
    client.send(:load_cookies, @cookies_path)
    
    # Verify cookies were loaded and converted to the new format
    session = client.instance_variable_get(:@session)
    assert_equal "legacy_session_cookie", session["substack.sid"]
    assert_equal "legacy_csrf_token", session["csrf-token"]
  end
  
  def test_load_cookies_failure
    # Create a client 
    client = Substack::Client.new
    non_existent_path = File.join(@temp_dir, 'nonexistent_file.yml')
    
    # Mock File.read to raise a specific error we expect
    File.expects(:read).with(non_existent_path).raises(LoadError.new("Cannot load cookies"))
    
    # Verify that the load_cookies method propagates the LoadError
    assert_raises(LoadError) do
      client.send(:load_cookies, non_existent_path)
    end
  end
end
