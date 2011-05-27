task :ruby_env do
  RUBY_APP = if RUBY_PLATFORM =~ /java/
    "jruby"
  else
    "ruby"
  end unless defined? RUBY_APP
end

desc 'Generate website files'
task :website_generate => :ruby_env do
  (Dir['website/**/*.txt'] - Dir['website/version*.txt']).each do |txt|
    sh %{ #{RUBY_APP} script/txt2html #{txt} > #{txt.gsub(/txt$/,'html')} }
  end
end

task :publish => %w{doc website_generate} do
  `cp -r doc website/doc`
  `rsync -avr --delete website/* panic@rubyforge.org:/var/www/gforge-projects/clevic/`
end

desc 'Generate and upload website files'
task :website => [:website_generate, 'rubyforge:doc_release', :publish_doc]
