# lib/substack_api/post.rb
require 'json'

module Substack
  # = Post Class
  #
  # The Post class provides methods for building a draft post on Substack. It allows
  # for adding various types of content including paragraphs, headings, images, and more.
  #
  # == Example Usage
  #
  #   client = Substack::Client.new
  #   post = Substack::Post.new(
  #     title: 'My First Post',
  #     subtitle: 'A test post',
  #     user_id: client.get_user_id
  #   )
  #
  #   post.paragraph('This is a paragraph.')
  #   post.heading('This is a heading', level: 2)
  #   post.horizontal_rule
  #   post.captioned_image(attrs: { src: 'image_url', alt: 'Image description' })
  #
  #   client.post_draft(post.get_draft)
  #
  class Post
    # @return [String] The title of the draft post
    # @return [String] The subtitle of the draft post
    # @return [Hash] The JSON body of the draft post
    # @return [Array<Hash>] Authors of the post
    # @return [String] Audience setting (e.g., "everyone", "only_paid", etc.)
    # @return [Integer, nil] Section ID for the post
    # @return [String] Comment permissions
    attr_accessor :draft_title, :draft_subtitle, :draft_body, :draft_bylines, :audience, :draft_section_id, :write_comment_permissions

    # Initialize a new draft post
    #
    # @param title [String] The post title
    # @param subtitle [String] The post subtitle
    # @param user_id [Integer, #to_i] The ID of the author
    # @param audience [String] The audience for the post ("everyone" by default)
    # @param write_comment_permissions [String, nil] Comment permissions (defaults to audience setting)
    # @raise [RuntimeError] If user_id is invalid
    def initialize(title:, subtitle:, user_id:, audience: "everyone", write_comment_permissions: nil)
      @draft_title = title
      @draft_subtitle = subtitle
      @draft_body = { type: "doc", content: [] }
      user_id = validate_user_id(user_id)

      @draft_bylines = [{
        "id" => user_id,
        "is_guest" => false
      }]
      @audience = audience
      @draft_section_id = nil
      @write_comment_permissions = write_comment_permissions || @audience
    end

    # Validate and convert user ID
    #
    # @param user_id [Integer, #to_i] The user ID to validate
    # @return [Integer] The validated user ID
    # @raise [RuntimeError] If user_id is invalid
    def validate_user_id(user_id)
      if user_id.respond_to?(:to_i)
        user_id = user_id.to_i
        raise "Invalid user_id: must be a positive integer" unless user_id.positive?
        user_id
      else
        raise "Invalid user_id: must respond to to_i"
      end
    end

    # Set the section for the post
    #
    # @param name [String] The name of the section
    # @param sections [Array<Hash>] List of available sections
    # @raise [RuntimeError] If the section doesn't exist
    def set_section(name, sections)
      section = sections.find { |s| s["name"] == name }
      raise "SectionNotExistsException: #{name}" unless section
      @draft_section_id = section["id"]
    end

    # Add a generic item to the post
    #
    # @param item [Hash] The item to add
    # @option item [String] :type The type of item (paragraph, heading, etc.)
    # @option item [String] :content The content text
    # @option item [Hash] :attrs Additional attributes
    # @option item [Integer] :level Heading level (if type is heading)
    def add(item)
      type = item[:type]
      content = item[:content]

      new_item = { type: type }
      new_item[:attrs] = item[:attrs] if item[:attrs]

      if type == "paragraph" && content
        new_item[:content] = [{ type: "text", text: content }]
      elsif type == "heading"
        new_item[:attrs] = { level: item[:level] || 1 }
        new_item[:content] = [{ type: "text", text: content }] if content
      end

      @draft_body[:content] << new_item
    end

    # Add a paragraph to the post
    #
    # @param content [String] The paragraph text
    # @return [void]
    def paragraph(content)
      add(type: "paragraph", content: content)
    end

    # Add a heading to the post
    #
    # @param content [String] The heading text
    # @param level [Integer] The heading level (1-6)
    # @return [void]
    def heading(content, level: 1)
      add(type: "heading", content: content, level: level)
    end

    # Add a horizontal rule to the post
    #
    # @return [void]
    def horizontal_rule
      add(type: "horizontal_rule")
    end

    # Add a captioned image to the post
    #
    # @param attrs [Hash] Image attributes
    # @option attrs [String] :src Image URL
    # @option attrs [String] :alt Alt text
    # @option attrs [String] :caption Image caption
    # @return [void]
    def captioned_image(attrs)
      add(type: "captionedImage", attrs: attrs)
    end

    # Add text to the last content item
    #
    # @param value [String] The text to add
    # @return [void]
    def text(value)
      last_item = @draft_body[:content].last
      last_item[:content] ||= []
      last_item[:content] << { type: "text", text: value }
    end

    # Add formatting marks to the last text item
    #
    # @param marks [Array<Hash>] The marks to add
    # @option marks [String] :type The type of mark (bold, italic, link, etc.)
    # @option marks [String] :href URL for link marks
    # @return [void]
    def marks(marks)
      last_item = @draft_body[:content].last
      return unless last_item && last_item[:content]
      last_content = last_item[:content].last
      return unless last_content

      last_content[:marks] ||= []
      marks.each do |mark|
        new_mark = { type: mark[:type] }
        new_mark[:attrs] = { href: mark[:href] } if mark[:type] == "link" && mark[:href]
        last_content[:marks] << new_mark
      end
    end

    # Add a YouTube video to the post
    #
    # @param video_id [String] The YouTube video ID
    # @return [void]
    def youtube(video_id)
      last_item = @draft_body[:content].last
      last_item[:attrs] ||= {}
      last_item[:attrs][:videoId] = video_id
    end

    # Add a subscription widget with a caption
    #
    # @param message [String, nil] The caption message
    # @return [void]
    def subscribe_with_caption(message: nil)
      message ||= "Thanks for reading this newsletter! Subscribe for free to receive new posts and support my work."
      add(
        type: "subscribeWidget",
        attrs: { url: "%%checkout_url%%", text: "Subscribe", language: "en" },
        content: [{ type: "ctaCaption", content: [{ type: "text", text: message }] }]
      )
    end

    # Get the draft post data for submission to the API
    #
    # @return [Hash] The complete draft post data
    def get_draft
      {
        draft_title: @draft_title,
        draft_subtitle: @draft_subtitle,
        draft_body: @draft_body.to_json,
        draft_bylines: @draft_bylines,
        audience: @audience,
        draft_section_id: @draft_section_id,
        section_chosen: true,
        write_comment_permissions: @write_comment_permissions
      }
    end
  end
end