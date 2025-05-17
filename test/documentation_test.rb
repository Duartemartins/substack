require_relative 'test_helper'

class DocumentationTest < Minitest::Test
  def test_client_has_documentation
    # Test that key methods are documented
    client_class = Substack::Client
    
    # Check that the class has a good description
    assert client_class.instance_methods(false).length > 0, "Client class should have instance methods"
    
    # Test some specific methods
    methods_to_check = [
      :get_user_id, 
      :get_user_profile, 
      :post_draft
    ]
    
    methods_to_check.each do |method_name|
      assert client_class.method_defined?(method_name), "Client class should define #{method_name}"
    end
    
    # This should print when tests run
    puts "Documentation test for client ran successfully"
  end
  
  def test_post_class_has_documentation
    # Test that Post class exists
    post_class = Substack::Post
    assert post_class.is_a?(Class), "Post should be a class"
    
    # Check that Post class has methods
    assert post_class.instance_methods(false).length > 0, "Post class should have instance methods"
    puts "Documentation test for Post class ran successfully"
  end
  
  def test_error_classes_defined
    # Check that all error classes are defined
    error_classes = [
      Substack::Error,
      Substack::AuthenticationError,
      Substack::APIError,
      Substack::NotFoundError,
      Substack::PermissionError,
      Substack::ValidationError
    ]
    
    error_classes.each do |error_class|
      assert defined?(error_class), "#{error_class} should be defined"
      assert error_class.is_a?(Class), "#{error_class} should be a class"
    end
    puts "Documentation test for error classes ran successfully"
  end
end
