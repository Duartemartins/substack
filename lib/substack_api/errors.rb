# lib/substack_api/errors.rb

module Substack
  # = Error Classes
  #
  # This file contains error classes for handling different types of errors
  # that may occur when interacting with the Substack API.
  #
  # == Usage Example
  #
  #   begin
  #     client.post_note(text: 'My new note')
  #   rescue Substack::AuthenticationError
  #     # Handle authentication issues
  #   rescue Substack::ValidationError => e
  #     puts e.error_details
  #   end
  
  # Base error class for all Substack API errors
  class Error < StandardError; end
  
  # Raised when authentication with Substack fails or when a valid session is required
  # but not available.
  class AuthenticationError < Error; end
  
  # Raised when a CAPTCHA challenge is detected during authentication.
  # This error includes information about the CAPTCHA type and provides
  # guidance on how to handle it.
  #
  # @attr_reader captcha_type [String] The type of CAPTCHA detected (hcaptcha, recaptcha, cloudflare)
  # @attr_reader can_retry [Boolean] Whether the operation can be retried with manual intervention
  #
  # @example Handling CAPTCHA errors
  #   begin
  #     client.login(email, password)
  #   rescue Substack::CaptchaRequiredError => e
  #     puts "CAPTCHA detected: #{e.captcha_type}"
  #     if e.can_retry
  #       # Retry with headless: false to allow manual solving
  #       client.login(email, password, headless: false)
  #     end
  #   end
  class CaptchaRequiredError < AuthenticationError
    attr_reader :captcha_type, :can_retry
    
    # CAPTCHA element selectors for different providers
    CAPTCHA_SELECTORS = {
      hcaptcha: ['iframe[src*="hcaptcha"]', '.h-captcha', '#hcaptcha'],
      recaptcha: ['iframe[src*="recaptcha"]', '.g-recaptcha', '#recaptcha'],
      cloudflare: ['#cf-challenge-running', '.cf-browser-verification', '#challenge-form', 'iframe[src*="challenges.cloudflare"]']
    }.freeze
    
    # Initialize a new CAPTCHA error
    #
    # @param message [String, nil] Error message
    # @param captcha_type [String] The type of CAPTCHA detected
    # @param can_retry [Boolean] Whether the operation can be retried
    def initialize(message = nil, captcha_type: 'unknown', can_retry: true)
      @captcha_type = captcha_type
      @can_retry = can_retry
      super(message || default_message)
    end
    
    # Generate a default error message based on the CAPTCHA type
    #
    # @return [String] A descriptive error message with guidance
    def default_message
      base_msg = "CAPTCHA verification required (type: #{@captcha_type})"
      if @can_retry
        "#{base_msg}. Retry with headless: false to solve manually."
      else
        base_msg
      end
    end
    
    # Check if a page contains a CAPTCHA challenge
    #
    # @param driver [Selenium::WebDriver] The Selenium WebDriver instance
    # @return [String, nil] The type of CAPTCHA detected, or nil if none found
    def self.detect_captcha(driver)
      CAPTCHA_SELECTORS.each do |captcha_type, selectors|
        selectors.each do |selector|
          begin
            element = driver.find_element(css: selector)
            return captcha_type.to_s if element
          rescue Selenium::WebDriver::Error::NoSuchElementError
            # Element not found, continue checking
          end
        end
      end
      nil
    end
  end
  
  # General API response error with status code and error details.
  # This is the parent class for more specific API errors.
  #
  # @attr_reader status [Integer, nil] HTTP status code of the error
  # @attr_reader errors [Array, nil] Detailed error information from the API
  class APIError < Error
    attr_reader :status, :errors
    
    # Initialize a new API error
    #
    # @param message [String, nil] Error message
    # @param status [Integer, nil] HTTP status code
    # @param errors [Array, nil] Detailed error information
    def initialize(message = nil, status: nil, errors: nil)
      @status = status
      @errors = errors
      super(message || default_message)
    end
    
    # Generate a default error message based on the status code
    #
    # @return [String] A descriptive error message
    def default_message
      if @status
        "API Error (HTTP #{@status})"
      else
        "Unknown API Error"
      end
    end
  end
  
  # Raised when the API enforces rate limiting (HTTP 429)
  class RateLimitError < APIError; end
  
  # Raised when a requested resource is not found (HTTP 404)
  class NotFoundError < APIError; end
  
  # Raised for permission-related errors (HTTP 403)
  class PermissionError < APIError; end
  
  # Raised when the API rejects input due to validation errors (HTTP 422)
  # 
  # This class provides additional methods to extract and format validation errors.
  class ValidationError < APIError
    # Format validation error details into a human-readable string
    #
    # @return [String] Formatted error details
    def error_details
      return "No validation errors" unless @errors && @errors.is_a?(Array) && !@errors.empty?
      
      @errors.map do |err|
        "#{err['location']} #{err['param']}: #{err['msg']}"
      end.join(", ")
    end
    
    # Generate a default error message including validation details
    #
    # @return [String] A detailed validation error message
    def default_message
      "Validation error: #{error_details}"
    end
  end
end
