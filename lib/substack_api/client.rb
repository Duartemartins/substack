# lib/substack_api/client.rb

require "selenium-webdriver"
require "json"
require "date"
require "net/http"
require "uri"
require "active_support"
require "active_support/core_ext/date"
require "active_support/core_ext/time"
require "zlib"
require "stringio"
require "logger"

module Substack
  class Client
    attr_accessor :base_url, :session, :cookies_path, :publication_url

    def initialize(email: nil, password: nil, cookies_path: nil, base_url: nil, publication_url: nil, debug: false)
      @base_url = base_url || "https://substack.com/api/v1"
      @cookies_path = cookies_path
      @session = {}
      @publication_url = publication_url || "https://interessant3.substack.com"
      @logger = Logger.new($stdout)
      @logger.level = debug ? Logger::DEBUG : Logger::WARN

      # puts "Publication URL: #{@publication_url}"

      if cookies_path && File.exist?(cookies_path)
        load_cookies(cookies_path)
      elsif email && password
        login(email, password)
      else
        raise ArgumentError, "Provide either cookies_path or email and password for authentication."
      end

      @publication_url ||= determine_primary_publication
    end

    def login(email, password)
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument('--headless')
      options.add_argument('--start-maximized')
      options.add_argument('--user-agent=Mozilla/5.0')
    
      service = Selenium::WebDriver::Chrome::Service.new(path: '/usr/local/bin/chromedriver')
      driver = Selenium::WebDriver.for :chrome, service: service, options: options
    
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
    
        cookies = driver.manage.all_cookies
        File.write('substack_cookies.json', cookies.to_json)
        puts "Cookies saved to 'substack_cookies.json'"
      ensure
        driver.quit
      end
    end

    def save_cookies(path = @cookies_path)
      File.write(path, @session.to_json) if path
    end

    def load_cookies(path)
      raw_cookies = JSON.parse(File.read(path))
      @session = raw_cookies.each_with_object({}) do |cookie, hash|
        hash[cookie['name']] = cookie['value']
      end
    end

    def get_user_id
      profile = get_user_profile
      profile["id"]
    end

    def get_user_profile
      uri = URI("#{@base_url}/user/profile/self")
      response = get_request(uri, "user profile")
      handle_response(response)
    end

    def determine_primary_publication
      profile = get_user_profile
      primary_pub = profile["primaryPublication"]

      if primary_pub["custom_domain"]
        "https://#{primary_pub['custom_domain']}/api/v1"
      else
        "https://#{primary_pub['subdomain']}.substack.com/api/v1"
      end
    end

    def construct_publication_url(publication)
      if publication["custom_domain"]
        "https://#{publication['custom_domain']}"
      else
        "https://#{publication['subdomain']}.substack.com"
      end
    end

    def post_draft(draft)
      uri = URI("#{@publication_url}/api/v1/drafts")
      # puts "Draft URI: #{uri}"
      # puts "Draft Payload: #{JSON.pretty_generate(draft)}"

      response = post_request(uri, draft)

      begin
        handle_response(response)
      rescue RuntimeError => e
        puts "Error while posting draft: #{e.message}"

        if response.body
          begin
            error_details = JSON.parse(response.body)
            if error_details["errors"]
              error_details["errors"].each do |error|
                puts "Error location: #{error['location']}"
                puts "Error parameter: #{error['param']}"
                puts "Error message: #{error['msg']}"
              end
            end
          rescue JSON::ParserError
            puts "Failed to parse error response body."
          end
        end

        puts JSON.pretty_generate(draft)
        raise
      end
    end

    def retry_with_backoff(max_retries: 3, delay: 1)
      attempts = 0
      begin
        attempts += 1
        puts "Attempt #{attempts} of #{max_retries}"
        yield
      rescue => e
        if attempts < max_retries
          sleep_time = delay * (2 ** (attempts - 1))
          puts "Error: #{e.message}. Retrying in #{sleep_time}s..."
          sleep(sleep_time)
          retry
        else
          puts "Max retries (#{max_retries}) reached. Final error: #{e.message}"
          raise
        end
      end
    end

    # def prepublish_draft(draft_id)
    #   uri = URI("#{@publication_url}/api/v1/drafts/#{draft_id}/prepublish")
    #   response = get_request(uri, "prepublish draft")

    #   # puts "Prepublish Draft Response Code: #{response.code}"
    #   # puts "Prepublish Draft Response Body: #{response.body}"

    #   begin
    #     handle_response(response)
    #   rescue => e
    #     puts "Prepublish error: #{e.message}"
    #     puts "Response Headers: #{response.each_header.to_h}"
    #     puts "Backtrace:\n#{e.backtrace.join("\n")}"
    #     raise
    #   end
    # end

    # def publish_draft(draft_id, send: true, share_automatically: false)
    #   uri = URI("#{@publication_url}/drafts/#{draft_id}/publish")
    #   response = post_request(uri, {
    #     "send" => send,
    #     "share_automatically" => share_automatically
    #   })
    #   handle_response(response)
    # end

    private

    def get_request(uri, name = nil)
      # puts "initialising get request for #{name}"
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "ruby-requests/1.0"
        request["Accept-Encoding"] = "gzip, deflate"
        request["Content-Type"] = "application/json"
        request["Accept"] = "*/*"
        request["Connection"] = "keep-alive"
        add_cookies(request)

        # puts "GET Request URI: #{uri}"
        # puts "Request Headers: #{request.each_header.to_h}"
        # puts "Request Cookies: #{request['Cookie']}"
        # puts "Request Body: #{request.body}" if request.body

        response = http.request(request)

        # puts "Response Code: #{response.code}"
        # puts "Raw Response Body (truncated): #{response.body[0..100]}..." if response.body.length > 100

        response
      end
    end

    def post_request(uri, body)
      puts "POST Request URL: #{uri}"
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        request = Net::HTTP::Post.new(uri)
        add_cookies(request)
        request.content_type = "application/json"
        request.body = body.to_json
        http.request(request)
      end
    rescue => e
      puts "Exception raised during POST: #{e.message}"
      puts "Backtrace:\n#{e.backtrace.join("\n")}"
      raise
    end

    def add_cookies(request)
      cookies = @session.map { |key, value| "#{key}=#{value}" }.join("; ")
      request["Cookie"] = cookies unless cookies.empty?
    end

    def handle_response(response)
      if response["content-encoding"] == "gzip"
        begin
          gz = Zlib::GzipReader.new(StringIO.new(response.body))
          decompressed_body = gz.read
          gz.close
          response.define_singleton_method(:body) { decompressed_body }
        rescue => e
          puts "Error decompressing gzip response: #{e.message}"
          raise
        end
      end

      begin
        parsed_body = JSON.parse(response.body)
      rescue JSON::ParserError => e
        puts "JSON Parsing Error: #{e.message}"
        puts "Raw Response Body: #{response.body}"
        raise
      end

      # puts "Parsed Response Body: #{parsed_body[0..50]}"
      parsed_body
    end
  end
end