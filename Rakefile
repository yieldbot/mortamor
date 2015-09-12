require 'bundler/gem_tasks'
require 'github/markup'
require 'redcarpet'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require_relative 'lib/mortamor'
require 'yard'
require 'yard/rake/yardoc_task'

args = [:spec, :make_bin_executable, :yard]

YARD::Rake::YardocTask.new do |t|
  OTHER_PATHS = %w()
  t.files = ['lib/**/*.rb', 'bin/**/*.rb', OTHER_PATHS]
  t.options = %w(--markup-provider=redcarpet --markup=markdown --main=README.md --files CHANGELOG.md)
end

RSpec::Core::RakeTask.new(:spec) do |r|
  r.pattern = FileList['**/**/*_spec.rb']
end

desc 'Retrieve the current version of mortamor'
task :version do
  puts Mortamor::Version.json_version
end

desc 'Bump the PATCH version of Mortamor'
task :bump do
  version_file = 'lib/mortmor/version.rb'

  # Read the file, bump the PATCH version
  contents = File.read(version_file).gsub(/(PATCH = )(\d+)/) { |_| Regexp.last_match[1] + (Regexp.last_match[2].to_i + 1).to_s }

  # Write the new contents of the file
  File.open(version_file, 'w') { |file| file.puts contents }
end

task default: args
