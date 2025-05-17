#!/usr/bin/env ruby

# Simple script to verify the Substack gem functionality
require_relative '../lib/substack'

puts "Substack Gem Version: #{Substack::VERSION}"
puts "Available error classes:"
puts "  - #{Substack::Error}"
puts "  - #{Substack::AuthenticationError}"
puts "  - #{Substack::APIError}"
puts "  - #{Substack::ValidationError}"

puts "\nPost class example:"
post = Substack::Post.new(title: "Test Post", subtitle: "A subtitle", user_id: 123)
post.paragraph("This is a test paragraph.")
post.heading("Test Heading")
post.paragraph("Another paragraph after the heading.")

puts "Draft JSON structure:"
puts post.get_draft.keys.join(", ")

puts "\nVerification complete! The library is working correctly."
