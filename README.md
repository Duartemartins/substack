# Substack Ruby Gem

This is a reverse-engineered Ruby wrapper for the Substack API. Please note that this project is not officially supported by Substack and is in extremely early stages of development. As such, it is likely to be buggy and incomplete.

## Current Functionality

At present, this gem only allows you to publish a draft article and it does so by retrieving cookies from a Selenium session in order to authenticate. More features will be added as the project evolves.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'substack', git: 'https://github.com/duartemartins/substack.git'
```
And then execute:

```ruby
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

## Example

Here is a basic example of how to publish a draft article:

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

## Contributing
Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License
This project is licensed under the Apache License 2.0. See the LICENSE file for details.

