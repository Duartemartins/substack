require_relative 'test_helper'

class ErrorCompleteTest < Minitest::Test
  def test_validation_error_with_non_array_errors
    # Test when errors is not an array
    error = Substack::ValidationError.new("Validation failed", 
                                         status: 422, 
                                         errors: "Error string instead of array")
    
    assert_equal "No validation errors", error.error_details
  end
  
  def test_validation_error_with_nil_message
    # Test with nil message forcing default_message to be used
    errors = [
      { "location" => "body", "param" => "title", "msg" => "Title is required" }
    ]
    
    error = Substack::ValidationError.new(nil, status: 422, errors: errors)
    expected_message = "Validation error: body title: Title is required"
    assert_equal expected_message, error.message
  end
  
  def test_validation_error_with_missing_fields
    # Test with errors that are missing expected fields
    errors = [
      { "param" => "title", "msg" => "Title is required" },  # missing location
      { "location" => "body", "msg" => "Content is invalid" } # missing param
    ]
    
    error = Substack::ValidationError.new(nil, status: 422, errors: errors)
    expected_details = " title: Title is required, body : Content is invalid"
    assert_equal expected_details, error.error_details
  end
  
  def test_api_error_inheritance
    # Test error class hierarchy
    assert Substack::RateLimitError.ancestors.include?(Substack::APIError)
    assert Substack::NotFoundError.ancestors.include?(Substack::APIError)
    assert Substack::PermissionError.ancestors.include?(Substack::APIError)
    assert Substack::ValidationError.ancestors.include?(Substack::APIError)
    
    assert Substack::APIError.ancestors.include?(Substack::Error)
    assert Substack::AuthenticationError.ancestors.include?(Substack::Error)
  end
  
  def test_validation_error_empty_errors_array
    # Test with an empty errors array
    error = Substack::ValidationError.new("Validation failed", status: 422, errors: [])
    assert_equal "No validation errors", error.error_details
  end
  
  def test_error_classes_respond_to_initialize
    # Test all error classes can be instantiated with message
    error_classes = [
      Substack::Error,
      Substack::AuthenticationError,
      Substack::APIError,
      Substack::RateLimitError,
      Substack::NotFoundError,
      Substack::PermissionError,
      Substack::ValidationError
    ]
    
    error_classes.each do |error_class|
      error = error_class.new("Test message")
      assert_instance_of error_class, error
      assert_equal "Test message", error.message
    end
  end
  
  # CaptchaRequiredError Tests
  def test_captcha_required_error_basic
    error = Substack::CaptchaRequiredError.new("CAPTCHA required")
    assert_instance_of Substack::CaptchaRequiredError, error
    assert_equal "CAPTCHA required", error.message
    assert_equal 'unknown', error.captcha_type
    assert_equal true, error.can_retry
  end
  
  def test_captcha_required_error_with_type
    error = Substack::CaptchaRequiredError.new(captcha_type: 'hcaptcha')
    assert_equal 'hcaptcha', error.captcha_type
    assert_includes error.message, 'hcaptcha'
  end
  
  def test_captcha_required_error_with_recaptcha
    error = Substack::CaptchaRequiredError.new(captcha_type: 'recaptcha')
    assert_equal 'recaptcha', error.captcha_type
    assert_includes error.message, 'recaptcha'
  end
  
  def test_captcha_required_error_with_cloudflare
    error = Substack::CaptchaRequiredError.new(captcha_type: 'cloudflare')
    assert_equal 'cloudflare', error.captcha_type
    assert_includes error.message, 'cloudflare'
  end
  
  def test_captcha_required_error_can_retry_true
    error = Substack::CaptchaRequiredError.new(can_retry: true)
    assert_equal true, error.can_retry
    assert_includes error.message, 'Retry with headless: false'
  end
  
  def test_captcha_required_error_can_retry_false
    error = Substack::CaptchaRequiredError.new(can_retry: false)
    assert_equal false, error.can_retry
    refute_includes error.message, 'Retry with headless: false'
  end
  
  def test_captcha_required_error_default_message
    error = Substack::CaptchaRequiredError.new(captcha_type: 'hcaptcha', can_retry: true)
    expected = "CAPTCHA verification required (type: hcaptcha). Retry with headless: false to solve manually."
    assert_equal expected, error.message
  end
  
  def test_captcha_required_error_default_message_no_retry
    error = Substack::CaptchaRequiredError.new(captcha_type: 'cloudflare', can_retry: false)
    expected = "CAPTCHA verification required (type: cloudflare)"
    assert_equal expected, error.message
  end
  
  def test_captcha_required_error_inherits_from_authentication_error
    assert Substack::CaptchaRequiredError.ancestors.include?(Substack::AuthenticationError)
    assert Substack::CaptchaRequiredError.ancestors.include?(Substack::Error)
  end
  
  def test_captcha_required_error_selectors_constant
    selectors = Substack::CaptchaRequiredError::CAPTCHA_SELECTORS
    
    assert selectors.key?(:hcaptcha)
    assert selectors.key?(:recaptcha)
    assert selectors.key?(:cloudflare)
    
    assert_includes selectors[:hcaptcha], 'iframe[src*="hcaptcha"]'
    assert_includes selectors[:recaptcha], 'iframe[src*="recaptcha"]'
    assert_includes selectors[:cloudflare], '#cf-challenge-running'
  end
  
  def test_captcha_detect_no_captcha
    mock_driver = mock('driver')
    
    # Stub find_element to always raise NoSuchElementError (no CAPTCHA found)
    Substack::CaptchaRequiredError::CAPTCHA_SELECTORS.values.flatten.each do |selector|
      mock_driver.stubs(:find_element).with(css: selector).raises(Selenium::WebDriver::Error::NoSuchElementError)
    end
    
    result = Substack::CaptchaRequiredError.detect_captcha(mock_driver)
    assert_nil result
  end
  
  def test_captcha_detect_hcaptcha
    mock_driver = mock('driver')
    mock_element = mock('element')
    
    # First selector for hcaptcha should return an element
    mock_driver.stubs(:find_element).with(css: 'iframe[src*="hcaptcha"]').returns(mock_element)
    
    result = Substack::CaptchaRequiredError.detect_captcha(mock_driver)
    assert_equal 'hcaptcha', result
  end
  
  def test_captcha_detect_recaptcha
    mock_driver = mock('driver')
    mock_element = mock('element')
    
    # hcaptcha selectors should fail
    Substack::CaptchaRequiredError::CAPTCHA_SELECTORS[:hcaptcha].each do |selector|
      mock_driver.stubs(:find_element).with(css: selector).raises(Selenium::WebDriver::Error::NoSuchElementError)
    end
    
    # First recaptcha selector should succeed
    mock_driver.stubs(:find_element).with(css: 'iframe[src*="recaptcha"]').returns(mock_element)
    
    result = Substack::CaptchaRequiredError.detect_captcha(mock_driver)
    assert_equal 'recaptcha', result
  end
  
  def test_captcha_detect_cloudflare
    mock_driver = mock('driver')
    mock_element = mock('element')
    
    # hcaptcha and recaptcha selectors should fail
    Substack::CaptchaRequiredError::CAPTCHA_SELECTORS[:hcaptcha].each do |selector|
      mock_driver.stubs(:find_element).with(css: selector).raises(Selenium::WebDriver::Error::NoSuchElementError)
    end
    Substack::CaptchaRequiredError::CAPTCHA_SELECTORS[:recaptcha].each do |selector|
      mock_driver.stubs(:find_element).with(css: selector).raises(Selenium::WebDriver::Error::NoSuchElementError)
    end
    
    # First cloudflare selector should succeed
    mock_driver.stubs(:find_element).with(css: '#cf-challenge-running').returns(mock_element)
    
    result = Substack::CaptchaRequiredError.detect_captcha(mock_driver)
    assert_equal 'cloudflare', result
  end
end
