require_relative 'test_helper'

# Tests for lib/substack_api/errors.rb
class ErrorsTest < Minitest::Test
  # ============================================
  # Base Error class tests
  # ============================================
  
  def test_error_base_class
    error = Substack::Error.new("Test error")
    assert_instance_of Substack::Error, error
    assert_equal "Test error", error.message
  end
  
  # ============================================
  # AuthenticationError tests
  # ============================================
  
  def test_authentication_error
    error = Substack::AuthenticationError.new("Authentication failed")
    assert_instance_of Substack::AuthenticationError, error
    assert_equal "Authentication failed", error.message
  end
  
  # ============================================
  # APIError tests
  # ============================================
  
  def test_api_error_with_status
    error = Substack::APIError.new("API failed", status: 500)
    assert_equal 500, error.status
    assert_equal "API failed", error.message
    assert_nil error.errors
  end
  
  def test_api_error_with_default_message
    error = Substack::APIError.new(nil, status: 500)
    assert_equal "API Error (HTTP 500)", error.message
  end
  
  def test_api_error_unknown
    error = Substack::APIError.new
    assert_equal "Unknown API Error", error.message
  end
  
  # ============================================
  # RateLimitError tests
  # ============================================
  
  def test_rate_limit_error
    error = Substack::RateLimitError.new("Rate limited", status: 429)
    assert_instance_of Substack::RateLimitError, error
    assert_equal 429, error.status
  end
  
  # ============================================
  # NotFoundError tests
  # ============================================
  
  def test_not_found_error
    error = Substack::NotFoundError.new("Resource not found", status: 404)
    assert_instance_of Substack::NotFoundError, error
    assert_equal 404, error.status
  end
  
  # ============================================
  # PermissionError tests
  # ============================================
  
  def test_permission_error
    error = Substack::PermissionError.new("Not allowed", status: 403)
    assert_instance_of Substack::PermissionError, error
    assert_equal 403, error.status
  end
  
  # ============================================
  # ValidationError tests
  # ============================================
  
  def test_validation_error_with_details
    errors = [
      { "location" => "body", "param" => "title", "msg" => "Title is required" },
      { "location" => "body", "param" => "content", "msg" => "Content is too short" }
    ]
    
    error = Substack::ValidationError.new("Validation failed", status: 422, errors: errors)
    assert_instance_of Substack::ValidationError, error
    assert_equal 422, error.status
    assert_equal errors, error.errors
    
    expected_details = "body title: Title is required, body content: Content is too short"
    assert_equal expected_details, error.error_details
  end
  
  def test_validation_error_with_default_message
    errors = [{ "location" => "body", "param" => "title", "msg" => "Title is required" }]
    error = Substack::ValidationError.new(nil, status: 422, errors: errors)
    
    expected_message = "Validation error: body title: Title is required"
    assert_equal expected_message, error.message
  end
  
  def test_validation_error_without_errors
    error = Substack::ValidationError.new(nil, status: 422)
    assert_equal "Validation error: No validation errors", error.message
    assert_equal "No validation errors", error.error_details
  end
  
  def test_validation_error_with_non_array_errors
    error = Substack::ValidationError.new("Validation failed", 
                                         status: 422, 
                                         errors: "Error string instead of array")
    assert_equal "No validation errors", error.error_details
  end
  
  def test_validation_error_with_missing_fields
    errors = [
      { "param" => "title", "msg" => "Title is required" },  # missing location
      { "location" => "body", "msg" => "Content is invalid" } # missing param
    ]
    
    error = Substack::ValidationError.new(nil, status: 422, errors: errors)
    expected_details = " title: Title is required, body : Content is invalid"
    assert_equal expected_details, error.error_details
  end
  
  def test_validation_error_empty_errors_array
    error = Substack::ValidationError.new("Validation failed", status: 422, errors: [])
    assert_equal "No validation errors", error.error_details
  end
  
  # ============================================
  # CaptchaRequiredError tests
  # ============================================
  
  def test_captcha_error_default_initialization
    error = Substack::CaptchaRequiredError.new
    
    assert_equal 'unknown', error.captcha_type
    assert_equal true, error.can_retry
    assert_includes error.message, 'CAPTCHA verification required'
    assert_includes error.message, 'headless: false'
  end
  
  def test_captcha_error_with_hcaptcha_type
    error = Substack::CaptchaRequiredError.new(captcha_type: 'hcaptcha')
    
    assert_equal 'hcaptcha', error.captcha_type
    assert_includes error.message, 'hcaptcha'
  end
  
  def test_captcha_error_with_recaptcha_type
    error = Substack::CaptchaRequiredError.new(captcha_type: 'recaptcha')
    
    assert_equal 'recaptcha', error.captcha_type
    assert_includes error.message, 'recaptcha'
  end
  
  def test_captcha_error_with_cloudflare_type
    error = Substack::CaptchaRequiredError.new(captcha_type: 'cloudflare')
    
    assert_equal 'cloudflare', error.captcha_type
    assert_includes error.message, 'cloudflare'
  end
  
  def test_captcha_error_with_can_retry_false
    error = Substack::CaptchaRequiredError.new(can_retry: false)
    
    assert_equal false, error.can_retry
    refute_includes error.message, 'Retry with headless: false'
  end
  
  def test_captcha_error_custom_message
    error = Substack::CaptchaRequiredError.new("Custom CAPTCHA message")
    
    assert_equal "Custom CAPTCHA message", error.message
  end
  
  def test_captcha_error_inherits_from_authentication_error
    error = Substack::CaptchaRequiredError.new
    
    assert_kind_of Substack::AuthenticationError, error
    assert_kind_of Substack::Error, error
    assert_kind_of StandardError, error
  end
  
  def test_captcha_selectors_constant_exists
    selectors = Substack::CaptchaRequiredError::CAPTCHA_SELECTORS
    
    assert selectors.is_a?(Hash)
    assert selectors.key?(:hcaptcha)
    assert selectors.key?(:recaptcha)
    assert selectors.key?(:cloudflare)
  end
  
  def test_captcha_selectors_have_expected_values
    selectors = Substack::CaptchaRequiredError::CAPTCHA_SELECTORS
    
    # hCaptcha selectors
    assert_includes selectors[:hcaptcha], 'iframe[src*="hcaptcha"]'
    assert_includes selectors[:hcaptcha], '.h-captcha'
    assert_includes selectors[:hcaptcha], '#hcaptcha'
    
    # reCAPTCHA selectors
    assert_includes selectors[:recaptcha], 'iframe[src*="recaptcha"]'
    assert_includes selectors[:recaptcha], '.g-recaptcha'
    assert_includes selectors[:recaptcha], '#recaptcha'
    
    # Cloudflare selectors
    assert_includes selectors[:cloudflare], '#cf-challenge-running'
    assert_includes selectors[:cloudflare], '.cf-browser-verification'
  end
  
  def test_captcha_detect_no_captcha
    mock_driver = mock('driver')
    
    Substack::CaptchaRequiredError::CAPTCHA_SELECTORS.values.flatten.each do |selector|
      mock_driver.stubs(:find_element).with(css: selector).raises(Selenium::WebDriver::Error::NoSuchElementError)
    end
    
    result = Substack::CaptchaRequiredError.detect_captcha(mock_driver)
    assert_nil result
  end
  
  def test_captcha_detect_hcaptcha
    mock_driver = mock('driver')
    mock_element = mock('element')
    
    mock_driver.stubs(:find_element).with(css: 'iframe[src*="hcaptcha"]').returns(mock_element)
    
    result = Substack::CaptchaRequiredError.detect_captcha(mock_driver)
    assert_equal 'hcaptcha', result
  end
  
  def test_captcha_detect_recaptcha
    mock_driver = mock('driver')
    mock_element = mock('element')
    
    Substack::CaptchaRequiredError::CAPTCHA_SELECTORS[:hcaptcha].each do |selector|
      mock_driver.stubs(:find_element).with(css: selector).raises(Selenium::WebDriver::Error::NoSuchElementError)
    end
    
    mock_driver.stubs(:find_element).with(css: 'iframe[src*="recaptcha"]').returns(mock_element)
    
    result = Substack::CaptchaRequiredError.detect_captcha(mock_driver)
    assert_equal 'recaptcha', result
  end
  
  def test_captcha_detect_cloudflare
    mock_driver = mock('driver')
    mock_element = mock('element')
    
    Substack::CaptchaRequiredError::CAPTCHA_SELECTORS[:hcaptcha].each do |selector|
      mock_driver.stubs(:find_element).with(css: selector).raises(Selenium::WebDriver::Error::NoSuchElementError)
    end
    Substack::CaptchaRequiredError::CAPTCHA_SELECTORS[:recaptcha].each do |selector|
      mock_driver.stubs(:find_element).with(css: selector).raises(Selenium::WebDriver::Error::NoSuchElementError)
    end
    
    mock_driver.stubs(:find_element).with(css: '#cf-challenge-running').returns(mock_element)
    
    result = Substack::CaptchaRequiredError.detect_captcha(mock_driver)
    assert_equal 'cloudflare', result
  end
  
  # ============================================
  # Inheritance tests
  # ============================================
  
  def test_api_error_inheritance
    assert Substack::RateLimitError.ancestors.include?(Substack::APIError)
    assert Substack::NotFoundError.ancestors.include?(Substack::APIError)
    assert Substack::PermissionError.ancestors.include?(Substack::APIError)
    assert Substack::ValidationError.ancestors.include?(Substack::APIError)
    
    assert Substack::APIError.ancestors.include?(Substack::Error)
    assert Substack::AuthenticationError.ancestors.include?(Substack::Error)
    assert Substack::CaptchaRequiredError.ancestors.include?(Substack::AuthenticationError)
  end
  
  def test_error_classes_respond_to_initialize
    error_classes = [
      Substack::Error,
      Substack::AuthenticationError,
      Substack::APIError,
      Substack::RateLimitError,
      Substack::NotFoundError,
      Substack::PermissionError,
      Substack::ValidationError,
      Substack::CaptchaRequiredError
    ]
    
    error_classes.each do |error_class|
      error = error_class.new("Test message")
      assert_instance_of error_class, error
      assert_equal "Test message", error.message
    end
  end
end
