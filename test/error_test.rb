require_relative 'test_helper'

class ErrorTest < Minitest::Test
  def test_error_base_class
    error = Substack::Error.new("Test error")
    assert_instance_of Substack::Error, error
    assert_equal "Test error", error.message
  end
  
  def test_authentication_error
    error = Substack::AuthenticationError.new("Authentication failed")
    assert_instance_of Substack::AuthenticationError, error
    assert_equal "Authentication failed", error.message
  end
  
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
  
  def test_rate_limit_error
    error = Substack::RateLimitError.new("Rate limited", status: 429)
    assert_instance_of Substack::RateLimitError, error
    assert_equal 429, error.status
  end
  
  def test_not_found_error
    error = Substack::NotFoundError.new("Resource not found", status: 404)
    assert_instance_of Substack::NotFoundError, error
    assert_equal 404, error.status
  end
  
  def test_permission_error
    error = Substack::PermissionError.new("Not allowed", status: 403)
    assert_instance_of Substack::PermissionError, error
    assert_equal 403, error.status
  end
  
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
end
