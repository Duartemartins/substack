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

  def test_post_draft
    # Stub out all the methods we'd call
    post = Substack::Post.new(title: 'Test Title', subtitle: 'Test Subtitle', user_id: 123)
    post.paragraph('This is a test paragraph.')
    
    @client.stubs(:determine_primary_publication_url).returns("https://test.substack.com/api/v1")
    @client.stubs(:request).returns({"id" => "draft123"})
    
    result = @client.post_draft(post.get_draft)
    assert_equal "draft123", result["id"]
  end
end