# substack_api.gemspec
require_relative "lib/substack_api/version"
Gem::Specification.new do |spec|
  spec.name          = "Substack"
  spec.version       = Substack::VERSION
  spec.summary       = "A Ruby wrapper for the Substack API"
  spec.description   = "This gem provides methods for Substack authentication, creating drafts, publishing posts, etc."
  spec.authors       = ["Duarte Martins"]
  spec.email         = ["duarteosrm@icloud.com"]
  spec.homepage      = "https://github.com/duartemartins/substack_api"
  spec.required_ruby_version = ">= 2.7"
  spec.license = "Apache-2.0"
  spec.files         = Dir["lib/**/*.rb"] + Dir["README.md", "LICENSE"]
  spec.bindir        = "exe"
  spec.executables   = []
  spec.require_paths = ["lib"]

  # Declare runtime dependencies here
  spec.add_dependency "selenium-webdriver", "~> 4.0"
  spec.add_dependency "net-http", "~> 0.3"      
  spec.add_dependency "json", "~> 2.0"          
  spec.add_dependency "activesupport", "~> 6.1"
  spec.add_dependency "logger", "~> 1.5"
  spec.add_dependency "faraday", "~> 2.7"
  spec.add_dependency "faraday-multipart", "~> 1.0"

  # Development dependencies (if needed)
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-reporters", "~> 1.5"
  spec.add_development_dependency "mocha", "~> 2.0"
  spec.add_development_dependency "rdoc", "~> 6.5"
  spec.add_development_dependency "yard", "~> 0.9.28"
  spec.add_development_dependency "redcarpet", "~> 3.6" # For markdown formatting in YARD
end