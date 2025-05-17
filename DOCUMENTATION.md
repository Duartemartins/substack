# Generating RDoc Documentation

This document describes how to generate and view the RDoc documentation for the Substack gem.

## Prerequisites

Make sure you have the `rdoc` gem installed:

```
gem install rdoc
```

## Generating Documentation

To generate the RDoc documentation for the Substack gem, run the following command from the root directory of the gem:

```
rdoc --title "Substack API Documentation" --main README.md --exclude /test/ --exclude Gemfile --exclude "*.gem"
```

This will:
- Set the title of the documentation to "Substack API Documentation"
- Use README.md as the main page
- Exclude test files, Gemfile, and gem files from the documentation
- Generate documentation for all Ruby files in the project

The documentation will be generated in a `doc` directory.

## Viewing Documentation

After generating the documentation, you can view it by opening the `doc/index.html` file in your web browser:

```bash
open doc/index.html
```

## Documentation Structure

The documentation is organized by module/class:

- `Substack` - Main module
  - `Client` - Main client class for interacting with the Substack API
    - `Base` - Authentication functionality
    - `API` - API request methods
  - `Post` - Class for creating post content
  - `Endpoints` - API endpoint constants
  - Error classes - Various error classes for handling API errors

## Adding More Documentation

When adding new features to the gem, make sure to document them using RDoc format. Here's a quick reference:

```ruby
# = Heading
#
# Description text
#
# == Subheading
#
# More description
#
# @param parameter_name [Type] Description
# @return [Type] Description
# @raise [ErrorType] Description
# @see OtherClass for more information
# @example
#   # Example code
#   client = Substack::Client.new
#   client.some_method
```

## Best Practices

1. Document all public methods with description, parameters, return values, and exceptions
2. Include examples for complex functionality
3. Keep the documentation up-to-date when changing code
4. Use consistent formatting
5. Regenerate documentation before releasing new versions

## References

- [RDoc Documentation](https://ruby.github.io/rdoc/)
- [RDoc Markup Reference](https://ruby.github.io/rdoc/RDoc/Markup.html)
