# Substack Ruby Gem

This is a reverse-engineered Ruby wrapper for the Substack API. Please note that this project is not officially supported by Substack and is in extremely early stages of development. As such, it is likely to be buggy and incomplete.

## Current Functionality

This gem provides access to various Substack API endpoints including:

- Creating and publishing draft articles
- Accessing your following feed
- Reading and managing inbox notifications
- Working with Notes (Substack's Twitter-like feature)
- Uploading and attaching images
- Reacting to Notes (likes)
- Accessing user settings

## Installation

Add this line to your application's Gemfile:

```
gem 'substack', git: 'https://github.com/duartemartins/substack.git'
```

And then execute:

```
bundle install
```

Or install it yourself as:

```ruby
gem install specific_install
gem specific_install -l https://github.com/duartemartins/substack.git
```

## Usage
To use the gem, you can start an interactive Ruby session with:

```
irb -r substack
```

### Authentication

The first time you use the gem, you'll need to authenticate with your Substack account:

```ruby
client = Substack::Client.new(email: 'your_email', password: 'your_password')
```

This will use Selenium to log in and save cookies to `~/.substack_cookies.yml`. For subsequent usage, you can just initialize the client:

```ruby
client = Substack::Client.new
```

### Working with Posts

```ruby
require 'substack'

client = Substack::Client.new(email: 'your_email', password: 'your_password')
post = Substack::Post.new(title: 'Draft Title', subtitle: 'Draft Subtitle', user_id: client.get_user_id)
post.paragraph('This is the first paragraph of the draft.')
post.heading('This is a heading', level: 2)
post.paragraph('This is another paragraph.')
post.horizontal_rule
post.captioned_image(attrs: { src: 'image_url', alt: 'Image description' })
post.text('This is some additional text.')
post.marks([{ type: 'bold' }, { type: 'italic' }])
post.youtube('video_id')
post.subscribe_with_caption(message: 'Subscribe for more updates!')

draft = post.get_draft
client.post_draft(draft)
```

### Working with Notes

Notes are Substack's Twitter-like feature. You can create and interact with them:

```ruby
# Post a simple note
client.post_note(text: 'Hello world! This is my first note on Substack.')

# Post a note with an image from a URL
client.post_note_with_image(
  text: 'Check out this cool image!',
  image_url: 'https://example.com/image.jpg'
)

# Upload a local image and post a note with it
client.post_note_with_local_image(
  text: 'I just took this photo!',
  image_path: '/path/to/local/image.jpg'
)

# React to a note (like it)
client.react_to_note('note_id')
```

### Accessing Your Feed and Inbox

```ruby
# Get your following feed
feed = client.following_feed(page: 1, limit: 25)

# Get your inbox notifications
notifications = client.inbox_top

# Mark notifications as seen
client.mark_inbox_seen([notification_id1, notification_id2])

# Check unread message count
unread = client.unread_count
```

### Accessing Public Endpoints

```ruby
# Get posts from a publication
posts = client.publication_posts('substackpub', limit: 10, offset: 0)
```

## Error Handling

The gem provides several error classes to help you handle different scenarios:

```ruby
begin
  client.post_note(text: 'My new note')
rescue Substack::AuthenticationError
  # Handle authentication issues
rescue Substack::RateLimitError
  # Handle rate limiting
rescue Substack::ValidationError => e
  # Handle validation errors
  puts e.error_details
rescue Substack::APIError => e
  # Handle general API errors
  puts "Status code: #{e.status}"
end
```

## Documentation

This gem is documented using RDoc and YARD. You can generate the documentation by running:

```bash
# Generate RDoc documentation
rake rdoc

# Open the documentation in your browser
rake docs_and_open

# If you have YARD installed
yard doc
```

For more information about the documentation, see the `DOCUMENTATION.md` file.

## Testing

The gem includes a comprehensive test suite that can be run with:

```bash
bundle exec rake test
```

All tests are implemented using Minitest and include mocks/stubs to avoid making actual API calls during testing. The test suite covers:

- Client authentication and initialization
- API endpoint functionality
- Post creation and formatting
- Image upload and attachment
- Documentation validation

For a summary of recent test suite fixes, see the `TEST_FIXES.md` file.

## Contributing
Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License
This project is licensed under the Apache License 2.0. See the LICENSE file for details.

