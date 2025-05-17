# lib/substack_api/client/api.rb
require 'json'
require 'faraday'
require 'fileutils'
require 'yaml'

module Substack
  class Client
    # = API Module
    #
    # The API module provides methods for interacting with Substack's API endpoints.
    # This includes methods for fetching feeds, posting notes, uploading images, and more.
    #
    # == Examples
    #
    #   client = Substack::Client.new
    #
    #   # Get your following feed
    #   feed = client.following_feed
    #
    #   # Post a note with an image
    #   client.post_note_with_image(
    #     text: 'Check out this cool image!',
    #     image_url: 'https://example.com/image.jpg'
    #   )
    #
    module API
      # The default path for storing session cookies
      # 
      # @return [String] Path to the default cookies file in the user's home directory
      DEFAULT_COOKIES_PATH = File.join(Dir.home, '.substack_cookies.yml')

      # Get the user's following feed
      #
      # @param page [Integer] The page number to fetch
      # @param limit [Integer] The number of items per page
      # @return [Hash] The feed data
      def following_feed(page: 1, limit: 25)
        request(:get, Endpoints::FEED_FOLLOWING, page: page, limit: limit)
      end

      # Get the user's inbox notifications
      #
      # @return [Hash] Inbox notifications data
      def inbox_top
        request(:get, Endpoints::INBOX_TOP)
      end

      # Mark specified notifications as read
      #
      # @param ids [Array<String>] IDs of notifications to mark as read
      # @return [Hash] Response data
      def mark_inbox_seen(ids = [])
        request(:put, Endpoints::INBOX_SEEN, json: { ids: ids })
      end

      # Get active live streams
      #
      # @return [Array] List of active live streams
      def live_streams
        request(:get, Endpoints::LIVE_STREAMS)
      end

      # Get count of unread messages
      #
      # @return [Hash] Counts of unread messages, pending invites, etc.
      def unread_count
        request(:get, Endpoints::UNREAD_COUNT)
      end

      # Upload an image to Substack
      #
      # @param file_path [String] Path to the image file to upload
      # @return [Hash] Information about the uploaded image
      # @raise [Error] If the upload fails
      def upload_image(file_path)
        file_content = File.binread(file_path)
        filename = File.basename(file_path)
        
        response = conn.post(Endpoints::IMAGE_UPLOAD) do |req|
          req.headers['Content-Type'] = 'application/octet-stream'
          req.headers['X-CSRF-Token'] = @session['csrf-token'] if @session['csrf-token'] 
          req.headers['X-File-Name'] = URI.encode_www_form_component(filename)
          req.body = file_content
        end
        
        handle_response(response)
      end

      # Convert an image URL to an attachment ID
      #
      # @param image_url [String] URL of the image to attach
      # @return [Hash] Attachment data including ID
      def attach_image(image_url)
        request(:post, Endpoints::ATTACH_IMAGE, json: { url: image_url })
      end

      # Post a note (Substack's equivalent of a tweet)
      #
      # @param text [String] The text content of the note
      # @param attachments [Array<Hash>] Attachment IDs to include
      # @return [Hash] Data about the created note
      def post_note(text:, attachments: [])
        payload = { contentMarkdown: text, attachments: attachments }
        request(:post, Endpoints::POST_NOTE, json: payload)
      end
      
      # Post a note with an image from a URL
      #
      # @param text [String] The text content of the note
      # @param image_url [String] URL of the image to attach
      # @return [Hash] Data about the created note
      def post_note_with_image(text:, image_url:)
        attachment = attach_image(image_url)
        post_note(text: text, attachments: [attachment])
      end
      
      # Upload a local image and post a note with it
      #
      # @param text [String] The text content of the note
      # @param image_path [String] Path to the local image file
      # @return [Hash] Data about the created note
      def post_note_with_local_image(text:, image_path:)
        uploaded = upload_image(image_path)
        attachment = attach_image(uploaded['url'])
        post_note(text: text, attachments: [attachment])
      end

      # React to a note (like, etc.)
      #
      # @param id [String] The ID of the note to react to
      # @param reaction_type [String] The type of reaction ('heart' by default)
      # @return [Hash] Response data
      def react_to_note(id, reaction_type = "heart")
        url = Endpoints::REACT_NOTE.call(id)
        request(:post, url, json: { type: reaction_type })
      end

      # Update user settings
      #
      # @param settings [Hash] Settings to update
      # @return [Hash] Response data
      def update_user_setting(settings = {})
        request(:put, Endpoints::USER_SETTING, json: settings)
      end

      # Get posts from a publication (public endpoint)
      #
      # @param publication [String] The publication subdomain
      # @param limit [Integer] The number of posts to fetch
      # @param offset [Integer] The offset for pagination
      # @return [Hash] Publication posts data
      def publication_posts(publication, limit: 25, offset: 0)
        url = Endpoints::POSTS_FEED.call(publication)
        request(:get, url, limit: limit, offset: offset)
      end

      private

      # Make a request to the Substack API
      #
      # @param method [Symbol] HTTP method (:get, :post, :put, etc.)
      # @param url [String] The URL to request
      # @param json [Hash, nil] JSON payload for the request
      # @param qs [Hash] Query string parameters
      # @return [Hash, Array] Parsed response data
      # @raise [Error] If the request fails
      def request(method, url, json: nil, **qs)
        ensure_authenticated
        
        response = conn.public_send(method) do |req|
          req.url url, qs
          req.headers['Content-Type'] = 'application/json'
          req.headers['User-Agent'] = 'ruby-substack-api/0.1.0'
          req.headers['X-CSRF-Token'] = @session['csrf-token'] if @session['csrf-token']
          req.body = JSON.dump(json) if json
        end
        
        handle_response(response)
      rescue Faraday::Error => e
        raise Substack::Error, e
      end

      # Get or create a Faraday connection with the current session
      #
      # @return [Faraday::Connection] The configured Faraday connection object
      def conn
        @conn ||= Faraday.new do |f|
          f.request :url_encoded
          f.response :json
          f.adapter Faraday.default_adapter
          
          # Set cookies from session
          if @session && @session['substack.sid']
            f.headers['Cookie'] = "substack.sid=#{@session['substack.sid']}"
            f.headers['Cookie'] += "; csrf-token=#{@session['csrf-token']}" if @session['csrf-token']
          end
        end
      end

      # Ensure the client is authenticated before making requests
      #
      # @raise [AuthenticationError] If no valid session is found
      def ensure_authenticated
        if !@session || !@session['substack.sid']
          if @cookies_path && File.exist?(@cookies_path || DEFAULT_COOKIES_PATH)
            load_cookies(@cookies_path || DEFAULT_COOKIES_PATH)
          else
            raise AuthenticationError, "No valid session found. Please authenticate first."
          end
        end
      end
      
      # Handle API responses and check for errors
      #
      # @param response [Faraday::Response] The API response
      # @return [Hash, Array] Parsed response data
      # @raise [AuthenticationError] For authentication failures
      # @raise [NotFoundError] For 404 errors
      # @raise [ValidationError] For validation errors
      # @raise [RateLimitError] For rate limiting
      # @raise [APIError] For other API errors
      def handle_response(response)
        # Check for error status codes
        status = response.status
        
        case status
        when 401, 403
          raise AuthenticationError, "Authentication failed (HTTP #{status})"
        when 404
          raise NotFoundError.new(nil, status: status)
        when 422
          # Validation errors
          parsed_body = JSON.parse(response.body.to_s) rescue {}
          errors = parsed_body['errors'] || []
          raise ValidationError.new(nil, status: status, errors: errors)
        when 429
          raise RateLimitError.new("Rate limit exceeded", status: status)
        when 400..499
          raise APIError.new("Client error", status: status)
        when 500..599
          raise APIError.new("Server error", status: status)
        end
        
        # If response is already a parsed JSON (from Faraday middleware)
        return response.body if response.body.is_a?(Hash) || response.body.is_a?(Array)
        
        # Otherwise parse it
        begin
          JSON.parse(response.body.to_s)
        rescue JSON::ParserError => e
          raise Error, "Invalid JSON response: #{e.message}"
        end
      end
    end
  end

  # Error classes
  class Error < StandardError; end
  class AuthenticationError < Error; end
  class APIError < Error; end
  class RateLimitError < APIError; end
  class NotFoundError < APIError; end
  class ValidationError < APIError; end
end
