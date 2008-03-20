require 'rubygems'
require 'hoe'

file 'ui/browser_ui.rb' => ['ui/browser.ui'] do |t|
  #~ puts "t.source: #{t.source.inspect}"
  #~ puts "t.sources: #{t.sources.inspect}"
  #~ puts "t.name: #{t.name.inspect}"
  #~ puts "t.prerequisites: #{t.prerequisites.inspect}"
  sh "rbuic4 #{t.prerequisites} -o #{t.name}"
end

Hoe.new('clevic', '1.0.1') do |s|
#~ spec = Gem::Specification.new do |s|
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

#~ task :default => 'ui/browser_ui.rb'
