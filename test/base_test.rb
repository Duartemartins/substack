require_relative 'test_helper'

# Tests for lib/substack_api/client/base.rb
class BaseTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @cookies_path = File.join(@temp_dir, 'test_cookies.yml')
    
    @log_output = StringIO.new
    @logger = Logger.new(@log_output)
    
    @original_test_mode = ENV['SUBSTACK_TEST_MODE']
    ENV['SUBSTACK_TEST_MODE'] = 'true'
  end
  
  def teardown
    FileUtils.remove_entry @temp_dir if File.directory?(@temp_dir)
    ENV['SUBSTACK_TEST_MODE'] = @original_test_mode
  end

  def client_for_test
    client = Object.new
    client.extend(Substack::Client::Base)
    client.instance_variable_set(:@logger, @logger)
    client.instance_variable_set(:@cookies_path, @cookies_path)
    client.instance_variable_set(:@session, {})
    client
  end

  # ============================================
  # Cookie Save Tests
  # ============================================
  
  def test_save_cookies_creates_file
    client = client_for_test
    client.instance_variable_set(:@session, {'substack.sid' => 'test_sid', 'csrf-token' => 'test_token'})
    
    client.save_cookies(@cookies_path)
    
    assert File.exist?(@cookies_path)
    saved_data = YAML.load(File.read(@cookies_path))
    assert_equal 'test_sid', saved_data['substack.sid']
    assert_equal 'test_token', saved_data['csrf-token']
  end
  
  def test_save_cookies_creates_directory
    client = client_for_test
    client.instance_variable_set(:@session, {'substack.sid' => 'test_sid'})
    
    nested_path = File.join(@temp_dir, 'nested', 'dir', 'cookies.yml')
    client.save_cookies(nested_path)
    
    assert File.exist?(nested_path)
  end
  
  def test_save_cookies_uses_default_path
    client = client_for_test
    client.instance_variable_set(:@session, {'substack.sid' => 'test_sid'})
    
    # Should use @cookies_path when no argument given
    client.save_cookies
    
    assert File.exist?(@cookies_path)
  end
  
  # ============================================
  # Cookie Load Tests
  # ============================================
  
  def test_load_cookies_yaml_format
    client = client_for_test
    
    # Write YAML format cookies
    File.write(@cookies_path, {'substack.sid' => 'yaml_sid', 'csrf-token' => 'yaml_token'}.to_yaml)
    
    client.load_cookies(@cookies_path)
    
    session = client.instance_variable_get(:@session)
    assert_equal 'yaml_sid', session['substack.sid']
    assert_equal 'yaml_token', session['csrf-token']
  end
  
  def test_load_cookies_json_format
    client = client_for_test
    
    # Write JSON format cookies (legacy format)
    File.write(@cookies_path, {'substack.sid' => 'json_sid', 'csrf-token' => 'json_token'}.to_json)
    
    client.load_cookies(@cookies_path)
    
    session = client.instance_variable_get(:@session)
    assert_equal 'json_sid', session['substack.sid']
    assert_equal 'json_token', session['csrf-token']
  end
  
  def test_load_cookies_invalid_format_raises
    client = client_for_test
    
    # Write binary/invalid content
    File.binwrite(@cookies_path, "\x00\x01\x02\x03")
    
    assert_raises(LoadError) do
      client.load_cookies(@cookies_path)
    end
  end
  
  # ============================================
  # Login Tests (test mode)
  # ============================================
  
  def test_login_in_test_mode_sets_session
    client = client_for_test
    
    client.login('test@example.com', 'password')
    
    session = client.instance_variable_get(:@session)
    assert_equal 'test_session_id', session['substack.sid']
    assert_equal 'test_csrf_token', session['csrf-token']
  end
  
  def test_login_in_test_mode_skips_selenium
    client = client_for_test
    
    Selenium::WebDriver::Chrome::Options.expects(:new).never
    Selenium::WebDriver.expects(:for).never
    
    client.login('test@example.com', 'password')
  end
  
  def test_login_accepts_headless_parameter
    client = client_for_test
    
    # Should work with headless: false
    client.login('test@example.com', 'password', headless: false)
    
    session = client.instance_variable_get(:@session)
    assert_equal 'test_session_id', session['substack.sid']
  end
  
  def test_login_accepts_wait_for_manual_captcha_parameter
    client = client_for_test
    
    client.login('test@example.com', 'password', wait_for_manual_captcha: 60)
    
    session = client.instance_variable_get(:@session)
    assert_equal 'test_session_id', session['substack.sid']
  end
  
  # ============================================
  # CAPTCHA Detection Tests
  # ============================================
  
  def test_detect_captcha_delegates_to_error_class
    client = client_for_test
    mock_driver = mock('driver')
    
    Substack::CaptchaRequiredError.expects(:detect_captcha).with(mock_driver).returns('hcaptcha')
    
    result = client.detect_captcha(mock_driver)
    assert_equal 'hcaptcha', result
  end
  
  def test_detect_captcha_returns_nil_when_no_captcha
    client = client_for_test
    mock_driver = mock('driver')
    
    Substack::CaptchaRequiredError.expects(:detect_captcha).with(mock_driver).returns(nil)
    
    result = client.detect_captcha(mock_driver)
    assert_nil result
  end
  
  # ============================================
  # handle_captcha Tests
  # ============================================
  
  def test_handle_captcha_raises_in_headless_mode
    client = client_for_test
    mock_driver = mock('driver')
    
    error = assert_raises(Substack::CaptchaRequiredError) do
      client.handle_captcha(mock_driver, 'hcaptcha', true, 120)
    end
    
    assert_equal 'hcaptcha', error.captcha_type
    assert_equal true, error.can_retry
    assert_includes error.message, 'headless: false'
  end
  
  def test_handle_captcha_waits_for_manual_solving
    client = client_for_test
    mock_driver = mock('driver')
    
    # Use a sequence to simulate CAPTCHA being solved after 2 checks
    seq = sequence('captcha_checks')
    client.expects(:detect_captcha).with(mock_driver).returns('hcaptcha').in_sequence(seq)
    client.expects(:detect_captcha).with(mock_driver).returns('hcaptcha').in_sequence(seq)
    client.expects(:detect_captcha).with(mock_driver).returns(nil).in_sequence(seq)  # Solved!
    
    # Stub sleep via our testable captcha_sleep method
    client.stubs(:captcha_sleep)
    
    # Use real time but with quick iterations
    # Should not raise - CAPTCHA gets solved
    client.handle_captcha(mock_driver, 'hcaptcha', false, 120)
    
    assert_includes @log_output.string, 'CAPTCHA detected'
  end
  
  def test_handle_captcha_timeout_raises_error
    client = client_for_test
    mock_driver = mock('driver')
    
    # CAPTCHA never gets solved
    client.stubs(:detect_captcha).with(mock_driver).returns('cloudflare')
    
    # Stub captcha_sleep to avoid actual waiting
    client.stubs(:captcha_sleep)
    
    # Mock current_time to make the while loop exit immediately
    # First call returns start_time (0), next call returns time past timeout
    start_time = Time.at(0)
    after_timeout = Time.at(100)
    client.stubs(:current_time).returns(start_time).then.returns(after_timeout)
    
    error = assert_raises(Substack::CaptchaRequiredError) do
      client.handle_captcha(mock_driver, 'cloudflare', false, 1)  # 1 second timeout
    end
    
    assert_equal 'cloudflare', error.captcha_type
    assert_equal false, error.can_retry
    assert_includes error.message, 'Timed out'
  end
  
  # ============================================
  # wait_for_login_success Tests
  # ============================================
  
  def test_wait_for_login_success_with_url_change
    client = client_for_test
    mock_driver = mock('driver')
    mock_wait = mock('wait')
    
    mock_driver.stubs(:current_url).returns('https://substack.com/home')
    mock_driver.stubs(:find_elements).returns([])
    
    mock_wait.expects(:until).yields.returns(true)
    
    # Should not raise
    client.wait_for_login_success(mock_driver, mock_wait)
  end
  
  def test_wait_for_login_success_with_user_element
    client = client_for_test
    mock_driver = mock('driver')
    mock_wait = mock('wait')
    mock_element = mock('element')
    
    mock_driver.stubs(:current_url).returns('https://substack.com/sign-in')
    mock_driver.stubs(:find_elements).with(css: '[data-testid="user-icon"], .user-avatar, .user-menu')
               .returns([mock_element])
    
    mock_wait.expects(:until).yields.returns(true)
    
    # Should not raise
    client.wait_for_login_success(mock_driver, mock_wait)
  end
  
  def test_wait_for_login_success_handles_timeout
    client = client_for_test
    mock_driver = mock('driver')
    mock_wait = mock('wait')
    
    mock_wait.expects(:until).raises(Selenium::WebDriver::Error::TimeoutError)
    
    # Should not raise - timeout is handled gracefully
    client.wait_for_login_success(mock_driver, mock_wait)
    
    assert_includes @log_output.string, 'timeout'
  end
  
  # ============================================
  # Constants Tests
  # ============================================
  
  def test_default_cookies_path_constant
    path = Substack::Client::Base::DEFAULT_COOKIES_PATH
    
    assert path.is_a?(String)
    assert_includes path, '.substack_cookies.yml'
  end
end
