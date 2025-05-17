# lib/substack_api/client/base.rb
require 'selenium-webdriver'
require 'logger'
require 'yaml'
require 'json'
require 'fileutils'

module Substack
  class Client
    # = Base Module
    #
    # The Base module provides authentication functionality for the Substack API client.
    # It handles logging in with email/password using Selenium WebDriver and manages
    # cookie storage and loading.
    #
    # == Authentication Flow
    #
    # 1. Try to load cookies from disk if a cookies path is provided
    # 2. If no cookies exist or loading fails, log in with email/password if provided
    # 3. Save the session cookies for future use
    #
    module Base
      # Default path for storing cookies in the user's home directory
      DEFAULT_COOKIES_PATH = File.join(Dir.home, '.substack_cookies.yml')
      
      # Initialize the client with authentication credentials
      #
      # @param email [String, nil] Substack account email
      # @param password [String, nil] Substack account password
      # @param cookies_path [String, nil] Path to store/load session cookies
      # @param debug [Boolean] Whether to output debug logs
      def initialize(email: nil, password: nil, cookies_path: nil, debug: false)
        @cookies_path = cookies_path || DEFAULT_COOKIES_PATH
        @session = {}
        @logger = Logger.new($stdout)
        @logger.level = debug ? Logger::DEBUG : Logger::WARN

        if cookies_path && File.exist?(cookies_path)
          load_cookies(cookies_path)
        elsif email && password
          login(email, password)
        else
          @logger.warn "No authentication provided. Some API features will be unavailable."
        end
      end

      # Log in to Substack using Selenium WebDriver
      #
      # This method opens a headless Chrome browser, navigates to the Substack login page,
      # enters the provided credentials, and extracts session cookies upon successful login.
      #
      # @param email [String] Substack account email
      # @param password [String] Substack account password
      # @raise [RuntimeError] If login fails
      def login(email, password)
        # Skip actual login in test mode
        if ENV['SUBSTACK_TEST_MODE'] == 'true'
          @logger.info "Running in test mode, skipping actual login"
          @session = {"substack.sid" => "test_session_id", "csrf-token" => "test_csrf_token"}
          return
        end
        
        @logger.info "Authenticating with Substack using Selenium..."
        options = Selenium::WebDriver::Chrome::Options.new
        options.add_argument('--headless')
        options.add_argument('--start-maximized')
        options.add_argument('--user-agent=Mozilla/5.0')
      
        begin
          driver = nil
          # Try to find chromedriver in different locations
          if File.exist?('/usr/local/bin/chromedriver')
            service = Selenium::WebDriver::Chrome::Service.new(path: '/usr/local/bin/chromedriver')
            driver = Selenium::WebDriver.for :chrome, service: service, options: options
          else
            # Fall back to letting Selenium find chromedriver automatically
            driver = Selenium::WebDriver.for :chrome, options: options
          end
      
          begin
            driver.get('https://substack.com/sign-in')
            wait = Selenium::WebDriver::Wait.new(timeout: 20)
        
            email_field = wait.until { driver.find_element(name: 'email') }
            email_field.send_keys(email)
        
            sign_in_button = wait.until { driver.find_element(link_text: 'Sign in with password') }
            sign_in_button.click
        
            password_field = wait.until { driver.find_element(name: 'password') }
            password_field.send_keys(password, :return)
        
            sleep 5
        
            @logger.info "Login successful, extracting cookies..."
            browser_cookies = driver.manage.all_cookies
            
            @session = {}
            browser_cookies.each do |cookie|
              @session[cookie['name']] = cookie['value']
            end
            
            save_cookies(@cookies_path)
            @logger.info "Cookies saved to '#{@cookies_path}'"
          ensure
            driver.quit
          end
        rescue => e
          @logger.error "Login failed: #{e.message}"
          raise "Failed to authenticate with Substack: #{e.message}"
        end
      end

      # Save session cookies to a file
      #
      # @param path [String] Path where cookies will be saved
      def save_cookies(path = @cookies_path)
        FileUtils.mkdir_p(File.dirname(path)) unless File.directory?(File.dirname(path))
        File.write(path, @session.to_yaml)
        @logger.debug "Saved cookies to #{path}"
      end

      # Load session cookies from a file
      #
      # Supports both YAML (preferred) and JSON formats for backward compatibility.
      #
      # @param path [String] Path to load cookies from
      # @raise [LoadError] If cookies cannot be loaded
      def load_cookies(path)
        @logger.debug "Loading cookies from #{path}"
        cookies_data = File.read(path)
        
        # Try parsing as YAML first (preferred format)
        begin
          @session = YAML.load(cookies_data)
        rescue => e
          # Fallback to JSON if YAML parsing fails
          @logger.debug "YAML parsing failed, trying JSON: #{e.message}"
          begin
            raw_cookies = JSON.parse(cookies_data)
            
            # Handle the legacy format where cookies were stored as array
            if raw_cookies.is_a?(Array)
              @session = raw_cookies.each_with_object({}) do |cookie, hash|
                hash[cookie['name']] = cookie['value']
              end
            else
              @session = raw_cookies
            end
          rescue
            raise LoadError, "Failed to load cookies from #{path}"
          end
        end
      end
    end
  end
end
