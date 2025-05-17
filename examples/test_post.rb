#!/usr/bin/env ruby

puts "Script started..."

# Load paths
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
puts "Load path set to: #{$LOAD_PATH.first}"

begin
  # Require individual files instead of the gem as a whole
  require_relative '../lib/substack_api/version'
  puts "Loaded version.rb"
  
  require_relative '../lib/substack_api/endpoints'
  puts "Loaded endpoints.rb"
  
  require_relative '../lib/substack_api/errors'
  puts "Loaded errors.rb"
  
  require_relative '../lib/substack_api/post'
  puts "Loaded post.rb"

  # Print version info
  puts "Substack API Version: #{Substack::VERSION}"

  # Test Post class
  puts "\nCreating a test post:"
  post = Substack::Post.new(title: "Test Post", subtitle: "A subtitle", user_id: 123)
  puts "Post created with title: #{post.instance_variable_get(:@draft_title)}"
  puts "Post created with subtitle: #{post.instance_variable_get(:@draft_subtitle)}"
  
  post.paragraph("This is a test paragraph.")
  puts "Added paragraph"
  
  post.heading("Test Heading")
  puts "Added heading"
  
  post.paragraph("Another paragraph after the heading.")
  puts "Added second paragraph"

  # Print post structure
  puts "\nPost draft structure:"
  draft = post.get_draft
  puts "Draft: #{draft.inspect}"
  
  if draft
    puts "- Title: #{draft[:draft_title]}"
    puts "- Subtitle: #{draft[:draft_subtitle]}"
    puts "- Body: #{draft[:draft_body]}"
  else
    puts "Draft is nil!"
  end

  puts "\nDone! Basic functionality is working correctly."
rescue => e
  puts "ERROR: #{e.message}"
  puts e.backtrace
end
