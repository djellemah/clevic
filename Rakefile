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

Hoe.new('clevic', '1.1.1') do |s|
	s.author     = "John Anderson"
	s.email      = "john at semiosix dot com"
	s.need_zip = true
	#~ s.url   = "http://www.semiosix.com"
	#~ s.platform   = Gem::Platform::RUBY
	#~ s.summary    = "A simple file browser somewhat integrated with Scite, Rails and Subversion"
	#~ s.files      = FileList["{bin,docs,lib,test}/**/*"].exclude("rdoc").to_a
	#~ s.require_path      = "lib"
	#~ s.autorequire       = "hilfer"
  #~ s.bindir      = 'bin'
  #~ s.executables << 'hilfer'
  #~ s.add_dependency( 'qt4-qtruby')
	#~ s.test_file         = "test/runtest.rb"
	#~ s.has_rdoc          = true
	#~ s.extra_rdoc_files  = ['README']
end

task :ui => [ 'ui/browser_ui.rb', 'ui/search_dialog_ui.rb' ]

desc "Runs Clevic"
task :run do |t|
  ARGV.shift()
  exec "ruby -w -Ilib bin/clevic #{ARGV.join(' ')}"
end

desc 'Runs irb in this project\'s context'
task :irb do |t|
  ARGV.shift()
  ENV['RUBYLIB'] += ":#{File.expand_path('.')}/lib"
  exec "irb -rclevic -rclevic/db_options.rb #{ARGV.join(' ')}"
end
