# filepath: /Users/duartemartins/Library/Mobile Documents/com~apple~CloudDocs/Code/Python/substack/substack_api/test/client_test.rb
require_relative 'test_helper'

class ClientTest < Minitest::Test
  def setup
    @client = Substack::Client.new(email: 'test@example.com', password: 'password')
  end

  def test_initialize
    assert_instance_of Substack::Client, @client
  end

  def test_get_user_id
    @client.stubs(:get_user_id).returns(123)
    user_id = @client.get_user_id
    assert_equal 123, user_id
  end

  def test_post_draft
    post = Substack::Post.new(title: 'Test Title', subtitle: 'Test Subtitle', user_id: 123)
    post.paragraph('This is a test paragraph.')
    draft = post.get_draft

    @client.stubs(:post_draft).returns({ success: true })
    response = @client.post_draft(draft)
    assert_equal({ success: true }, response)
  end
end