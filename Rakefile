require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

desc 'Run tests'
task default: :test

begin
  require 'rdoc/task'

  RDoc::Task.new do |rdoc|
    rdoc.rdoc_dir = 'doc'
    rdoc.title = 'Substack API Documentation'
    rdoc.main = 'README.md'
    rdoc.rdoc_files.include('README.md', 'lib/**/*.rb', 'DOCUMENTATION.md')
    rdoc.options << '--all' # Include private methods
    rdoc.options << '--exclude=/test/'
    rdoc.options << '--exclude=Gemfile'
    rdoc.options << '--exclude=*.gem'
  end

  desc 'Generate documentation and open in browser'
  task :docs_and_open do
    Rake::Task['rdoc'].invoke
    sh 'open doc/index.html'
  end
rescue LoadError
  puts 'RDoc not available. Install with: gem install rdoc'
end

desc 'Print API endpoints'
task :endpoints do
  require_relative 'lib/substack_api/endpoints'
  
  puts "Substack API Endpoints:"
  puts "======================="
  puts
  
  Substack::Endpoints.constants.each do |const|
    value = Substack::Endpoints.const_get(const)
    if value.is_a?(String)
      puts "#{const}: #{value}"
    elsif value.is_a?(Proc)
      puts "#{const}: [lambda] Example: #{value.call('example')}"
    end
  end
end
