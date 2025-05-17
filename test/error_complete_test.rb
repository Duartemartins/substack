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
end
