# lib/substack_api/post.rb

module Substack
  class Post
    attr_accessor :draft_title, :draft_subtitle, :draft_body, :draft_bylines, :audience, :draft_section_id, :write_comment_permissions

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

    def validate_user_id(user_id)
      if user_id.respond_to?(:to_i)
        user_id = user_id.to_i
        raise "Invalid user_id: must be a positive integer" unless user_id.positive?
        user_id
      else
        raise "Invalid user_id: must respond to to_i"
      end
    end

    def set_section(name, sections)
      section = sections.find { |s| s["name"] == name }
      raise "SectionNotExistsException: #{name}" unless section
      @draft_section_id = section["id"]
    end

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

    def paragraph(content)
      add(type: "paragraph", content: content)
    end

    def heading(content, level: 1)
      add(type: "heading", content: content, level: level)
    end

    def horizontal_rule
      add(type: "horizontal_rule")
    end

    def captioned_image(attrs)
      add(type: "captionedImage", attrs: attrs)
    end

    def text(value)
      last_item = @draft_body[:content].last
      last_item[:content] ||= []
      last_item[:content] << { type: "text", text: value }
    end

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

    def youtube(video_id)
      last_item = @draft_body[:content].last
      last_item[:attrs] ||= {}
      last_item[:attrs][:videoId] = video_id
    end

    def subscribe_with_caption(message: nil)
      message ||= "Thanks for reading this newsletter! Subscribe for free to receive new posts and support my work."
      add(
        type: "subscribeWidget",
        attrs: { url: "%%checkout_url%%", text: "Subscribe", language: "en" },
        content: [{ type: "ctaCaption", content: [{ type: "text", text: message }] }]
      )
    end

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