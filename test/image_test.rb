require_relative 'test_helper'

class ImageTest < Minitest::Test
  def setup
    # Use stub authentication from test_client.rb
    @client = Substack::Client.new
  end

  def test_upload_image
    file_path = 'test/fixtures/test_image.jpg'
    mock_file_content = "binary image content"
    
    File.stubs(:binread).with(file_path).returns(mock_file_content)
    File.stubs(:basename).with(file_path).returns('test_image.jpg')
    
    mock_conn = mock('conn')
    mock_response = mock('response')
    mock_request = mock('request')
    
    # Set up mock response to handle content-encoding check
    mock_response.stubs(:[]).with("content-encoding").returns(nil)
    mock_response.stubs(:status).returns(200)
    mock_response.stubs(:body).returns('{"id":"img123","url":"https://substack.com/img/test_image.jpg"}')
    
    # Set up mock request expectations
    mock_request.expects(:headers).returns({}).at_least_once
    mock_request.expects(:body=).with(mock_file_content)
    
    mock_conn.expects(:post).with(Substack::Endpoints::IMAGE_UPLOAD).yields(mock_request).returns(mock_response)
    
    @client.stubs(:conn).returns(mock_conn)
    
    # Skip handle_response and manually return expected response
    @client.stubs(:handle_response).with(mock_response).returns({"id" => "img123", "url" => "https://substack.com/img/test_image.jpg"})
    
    response = @client.upload_image(file_path)
    assert_equal "img123", response["id"]
    assert_equal "https://substack.com/img/test_image.jpg", response["url"]
  end

  def test_attach_image
    image_url = 'https://example.com/image.jpg'
    mock_response = { 'id' => 'attachment123' }
    
    @client.expects(:request).with(:post, Substack::Endpoints::ATTACH_IMAGE, json: { url: image_url }).returns(mock_response)
    
    response = @client.attach_image(image_url)
    assert_equal mock_response, response
  end

  def test_post_note_with_image
    # Test the complete flow of posting a note with an image
    text = 'Check out this image!'
    image_url = 'https://example.com/image.jpg'
    attachment_id = 'attachment123'
    
    # First, attach the image
    @client.expects(:attach_image).with(image_url).returns({ 'id' => attachment_id })
    
    # Then, post the note with the attachment
    expected_payload = {
      contentMarkdown: text,
      attachments: [{ 'id' => attachment_id }]
    }
    
    @client.expects(:request).with(:post, Substack::Endpoints::POST_NOTE, json: expected_payload).returns({ 'id' => 'note123' })
    
    # Create a helper method to simplify this flow for users
    def @client.post_note_with_image(text:, image_url:)
      attachment = attach_image(image_url)
      post_note(text: text, attachments: [attachment])
    end
    
    response = @client.post_note_with_image(text: text, image_url: image_url)
    assert_equal 'note123', response['id']
  end
end
