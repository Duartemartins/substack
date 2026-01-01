require_relative 'test_helper'

class PostTest < Minitest::Test
  def setup
    @user_id = 123
    @post = Substack::Post.new(
      title: 'Test Title',
      subtitle: 'Test Subtitle',
      user_id: @user_id
    )
  end

  def test_initialize
    assert_instance_of Substack::Post, @post
    assert_equal 'Test Title', @post.draft_title
    assert_equal 'Test Subtitle', @post.draft_subtitle
    assert_equal [{ "id" => @user_id, "is_guest" => false }], @post.draft_bylines
    assert_equal "everyone", @post.audience
    assert_equal "everyone", @post.write_comment_permissions
  end

  def test_initialize_with_options
    post = Substack::Post.new(
      title: 'Test Title',
      subtitle: 'Test Subtitle',
      user_id: @user_id,
      audience: 'only_paid',
      write_comment_permissions: 'off'
    )
    
    assert_equal 'only_paid', post.audience
    assert_equal 'off', post.write_comment_permissions
  end

  def test_validate_user_id
    # Valid integer
    assert_equal 123, @post.validate_user_id(123)
    
    # Valid string that can be converted to integer
    assert_equal 123, @post.validate_user_id("123")
    
    # Non-positive integer
    assert_raises(RuntimeError) { @post.validate_user_id(0) }
    assert_raises(RuntimeError) { @post.validate_user_id(-1) }
    
    # Invalid type
    assert_raises(RuntimeError) { @post.validate_user_id(nil) }
    assert_raises(RuntimeError) { @post.validate_user_id([]) }
  end

  def test_set_section
    sections = [
      { "id" => 111, "name" => "Technology" },
      { "id" => 222, "name" => "Science" }
    ]
    
    @post.set_section("Science", sections)
    assert_equal 222, @post.draft_section_id
    
    assert_raises(RuntimeError) { @post.set_section("Sports", sections) }
  end

  def test_paragraph
    @post.paragraph('This is a test paragraph.')
    content = @post.draft_body[:content]
    
    assert_equal 1, content.length
    assert_equal 'paragraph', content[0][:type]
    assert_equal 1, content[0][:content].length
    assert_equal 'text', content[0][:content][0][:type]
    assert_equal 'This is a test paragraph.', content[0][:content][0][:text]
  end

  def test_heading
    @post.heading('This is a test heading', level: 2)
    content = @post.draft_body[:content]
    
    assert_equal 1, content.length
    assert_equal 'heading', content[0][:type]
    assert_equal 2, content[0][:attrs][:level]
    assert_equal 'This is a test heading', content[0][:content][0][:text]
  end

  def test_horizontal_rule
    @post.horizontal_rule
    content = @post.draft_body[:content]
    
    assert_equal 1, content.length
    assert_equal 'horizontal_rule', content[0][:type]
  end

  def test_captioned_image
    image_attrs = { 
      src: 'https://example.com/image.jpg',
      alt: 'Test image',
      caption: 'This is a test image'
    }
    
    @post.captioned_image(image_attrs)
    content = @post.draft_body[:content]
    
    assert_equal 1, content.length
    assert_equal 'captionedImage', content[0][:type]
    assert_equal image_attrs, content[0][:attrs]
  end

  def test_text
    @post.paragraph('First part')
    @post.text(' continued text')
    content = @post.draft_body[:content]
    
    assert_equal 1, content.length
    assert_equal 2, content[0][:content].length
    assert_equal 'First part', content[0][:content][0][:text]
    assert_equal ' continued text', content[0][:content][1][:text]
  end

  def test_marks
    @post.paragraph('This is a link')
    @post.marks([{ type: 'bold' }, { type: 'italic' }])
    content = @post.draft_body[:content]
    
    assert_equal 1, content.length
    assert_equal 2, content[0][:content][0][:marks].length
    assert_equal 'bold', content[0][:content][0][:marks][0][:type]
    assert_equal 'italic', content[0][:content][0][:marks][1][:type]
  end

  def test_marks_with_link
    @post.paragraph('This is a link')
    @post.marks([{ type: 'link', href: 'https://example.com' }])
    content = @post.draft_body[:content]
    
    assert_equal 1, content.length
    assert_equal 1, content[0][:content][0][:marks].length
    assert_equal 'link', content[0][:content][0][:marks][0][:type]
    assert_equal 'https://example.com', content[0][:content][0][:marks][0][:attrs][:href]
  end

  def test_youtube
    @post.paragraph('Check out this video:')
    @post.youtube('dQw4w9WgXcQ')
    content = @post.draft_body[:content]
    
    assert_equal 1, content.length
    assert_equal 'dQw4w9WgXcQ', content[0][:attrs][:videoId]
  end

  def test_subscribe_with_caption
    @post.subscribe_with_caption(message: 'Custom subscription message')
    content = @post.draft_body[:content]
    
    assert_equal 1, content.length
    assert_equal 'subscribeWidget', content[0][:type]
    assert_equal '%%checkout_url%%', content[0][:attrs][:url]
    assert_equal 'Subscribe', content[0][:attrs][:text]
    assert_equal 'en', content[0][:attrs][:language]
  end

  def test_subscribe_with_caption_default
    @post.subscribe_with_caption
    content = @post.draft_body[:content]
    
    assert_equal 1, content.length
    assert_equal 'subscribeWidget', content[0][:type]
    assert_equal '%%checkout_url%%', content[0][:attrs][:url]
    assert_equal 'Subscribe', content[0][:attrs][:text]
    assert_equal 'en', content[0][:attrs][:language]
  end

  def test_get_draft
    @post.paragraph('This is a test paragraph.')
    draft = @post.get_draft
    
    assert_equal 'Test Title', draft[:draft_title]
    assert_equal 'Test Subtitle', draft[:draft_subtitle]
    assert_equal [{ "id" => @user_id, "is_guest" => false }], draft[:draft_bylines]
    assert_equal "everyone", draft[:audience]
    assert_equal "everyone", draft[:write_comment_permissions]
    assert_equal true, draft[:section_chosen]
    
    # Verify the body is properly JSON encoded
    parsed_body = JSON.parse(draft[:draft_body])
    assert_equal "doc", parsed_body["type"]
    assert_equal 1, parsed_body["content"].length
    assert_equal "paragraph", parsed_body["content"][0]["type"]
  end
  
  # Additional tests for edge cases
  def test_add_with_attrs
    @post.add(type: "custom_type", attrs: { key: "value" })
    content = @post.draft_body[:content]
    
    assert_equal 1, content.length
    assert_equal "custom_type", content[0][:type]
    assert_equal({ key: "value" }, content[0][:attrs])
  end
  
  def test_add_heading_without_content
    @post.add(type: "heading", level: 3)
    content = @post.draft_body[:content]
    
    assert_equal 1, content.length
    assert_equal "heading", content[0][:type]
    assert_equal({ level: 3 }, content[0][:attrs])
    refute content[0].key?(:content)
  end
  
  def test_add_heading_with_default_level
    @post.add(type: "heading", content: "Test")
    content = @post.draft_body[:content]
    
    assert_equal({ level: 1 }, content[0][:attrs])
  end
  
  def test_marks_on_empty_content
    # marks should do nothing if there's no content
    @post.marks([{ type: 'bold' }])
    
    # Should not raise and content should be empty
    assert_equal 0, @post.draft_body[:content].length
  end
  
  def test_marks_on_item_without_content
    @post.add(type: "horizontal_rule")
    @post.marks([{ type: 'bold' }])
    
    # Should not raise
    content = @post.draft_body[:content]
    assert_equal 1, content.length
    refute content[0].key?(:marks)
  end
  
  def test_text_creates_content_array_if_missing
    @post.add(type: "custom_type")
    @post.text("Some text")
    
    content = @post.draft_body[:content]
    assert_equal 1, content[0][:content].length
    assert_equal "Some text", content[0][:content][0][:text]
  end
  
  def test_youtube_creates_attrs_if_missing
    @post.add(type: "embed")
    @post.youtube('abc123')
    
    content = @post.draft_body[:content]
    assert_equal 'abc123', content[0][:attrs][:videoId]
  end
  
  def test_multiple_paragraphs
    @post.paragraph('First paragraph')
    @post.paragraph('Second paragraph')
    @post.paragraph('Third paragraph')
    
    content = @post.draft_body[:content]
    assert_equal 3, content.length
    assert_equal 'First paragraph', content[0][:content][0][:text]
    assert_equal 'Second paragraph', content[1][:content][0][:text]
    assert_equal 'Third paragraph', content[2][:content][0][:text]
  end
  
  def test_heading_levels
    @post.heading('H1', level: 1)
    @post.heading('H2', level: 2)
    @post.heading('H3', level: 3)
    @post.heading('H4', level: 4)
    @post.heading('H5', level: 5)
    @post.heading('H6', level: 6)
    
    content = @post.draft_body[:content]
    assert_equal 6, content.length
    
    (1..6).each do |level|
      assert_equal level, content[level-1][:attrs][:level]
    end
  end
  
  def test_multiple_marks_types
    @post.paragraph('Complex text')
    @post.marks([
      { type: 'bold' },
      { type: 'italic' },
      { type: 'code' }
    ])
    
    content = @post.draft_body[:content]
    marks = content[0][:content][0][:marks]
    
    assert_equal 3, marks.length
    assert_equal 'bold', marks[0][:type]
    assert_equal 'italic', marks[1][:type]
    assert_equal 'code', marks[2][:type]
  end
  
  def test_link_mark_without_href
    @post.paragraph('Text')
    @post.marks([{ type: 'link' }])
    
    content = @post.draft_body[:content]
    marks = content[0][:content][0][:marks]
    
    assert_equal 1, marks.length
    assert_equal 'link', marks[0][:type]
    refute marks[0].key?(:attrs)
  end
  
  def test_draft_section_id_nil_by_default
    assert_nil @post.draft_section_id
  end
  
  def test_validate_user_id_with_float
    # Float can be converted to int
    result = @post.validate_user_id(123.7)
    assert_equal 123, result
  end
  
  def test_complex_document_structure
    @post.heading('Introduction', level: 1)
    @post.paragraph('Welcome to my post.')
    @post.horizontal_rule
    @post.heading('Chapter 1', level: 2)
    @post.paragraph('This is the first chapter.')
    @post.captioned_image(src: 'https://example.com/image.jpg')
    @post.subscribe_with_caption
    
    content = @post.draft_body[:content]
    
    assert_equal 7, content.length
    assert_equal 'heading', content[0][:type]
    assert_equal 'paragraph', content[1][:type]
    assert_equal 'horizontal_rule', content[2][:type]
    assert_equal 'heading', content[3][:type]
    assert_equal 'paragraph', content[4][:type]
    assert_equal 'captionedImage', content[5][:type]
    assert_equal 'subscribeWidget', content[6][:type]
  end
end