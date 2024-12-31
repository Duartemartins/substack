require_relative 'test_helper'

class PostTest < Minitest::Test
  def setup
    @post = Substack::Post.new(title: 'Test Title', subtitle: 'Test Subtitle', user_id: 1)
  end

  def test_initialize
    assert_instance_of Substack::Post, @post
  end

  def test_paragraph
    @post.paragraph('This is a test paragraph.')
    assert_equal 'paragraph', @post.draft_body[:content].last[:type]
  end

  def test_heading
    @post.heading('This is a test heading', level: 2)
    assert_equal 'heading', @post.draft_body[:content].last[:type]
    assert_equal 2, @post.draft_body[:content].last[:attrs][:level]
  end

  def test_get_draft
    draft = @post.get_draft
    assert draft.is_a?(Hash)
    assert_equal 'Test Title', draft[:draft_title]
  end
end