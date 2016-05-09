require 'bundler/gem_tasks'
require 'rake/clean'
require 'fileutils'

CLEAN.include %w[**/.DS_Store tmp *.log doc website/doc]

Dir['tasks/**/*.rake'].each { |t| load t }
