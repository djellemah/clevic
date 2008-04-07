require 'rubygems'
require 'rake/clean'
require 'hoe'

CLEAN.include( 'ui/*.rb' )

file 'ui/browser_ui.rb' => ['ui/browser.ui'] do |t|
  sh "rbuic4 #{t.prerequisites} -o #{t.name}"
end

file 'ui/search_dialog_ui.rb' => ['ui/search_dialog.ui'] do |t|
  sh "rbuic4 #{t.prerequisites} -o #{t.name}"
end

Hoe.new('clevic', '0.4.2') do |s|
	s.author     = "John Anderson"
	s.email      = "john at semiosix dot com"
	s.need_zip = true
end

task :ui => [ 'ui/browser_ui.rb', 'ui/search_dialog_ui.rb' ]

desc "Runs Clevic"
task :run do |t|
  ARGV.shift()
  exec "ruby -w -Ilib bin/clevic -D #{ARGV.join(' ')}"
end

desc 'Runs irb in this project\'s context'
task :irb do |t|
  ARGV.shift()
  ENV['RUBYLIB'] += ":#{File.expand_path('.')}/lib"
  exec "irb -Ilib -rclevic"
end

desc 'irb with times_models'
task :times do |t|
  ARGV.shift()
  
  ENV['RUBYLIB'] ||= ''
  ENV['RUBYLIB'] += ":#{File.expand_path('.')}/lib"
  
  exec "irb -Ilib -rclevic -r times_models.rb -rclevic/db_options.rb"
end

desc 'irb with accounts_models'
task :accounts do |t|
  ARGV.shift()
  ENV['RUBYLIB'] += ":#{File.expand_path('.')}/lib"
  exec "irb -Ilib -rclevic -raccounts_models.rb -rclevic/db_options.rb"
end
