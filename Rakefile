#~ %w[rake rake/clean fileutils].each { |f| require f }

begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

#~ task :default => 'test:run'
#~ task 'gem:release' => 'test:run'

ensure_in_path 'lib'
require 'clevic/version.rb'

# rake bones:help |less

Bones do
  name  'clevic'
  authors  'John Anderson'
  email  'panic@semiosix.com'
  url  'http://clevic.rubyforge.org'
  version  Clevic::VERSION::STRING
  description "SQL table GUI with Qt / Java Swing and Sequel"
  
  gem.need_tar false
  
  depend_on 'fastercsv', '>=1.2.3'
  depend_on 'gather', '>=0.0.6'
  depend_on 'andand', '>= 1.3.0'
  depend_on 'sequel', '>= 3.8.0'
  depend_on 'bsearch', '>=1.5.0'
  # for html paste parsing
  depend_on 'hpricot', '>= 0.8.1'
  
  # for 1.8
  depend_on 'hashery', '>=1.3.0'

  # for JRuby clipboard handling
  depend_on 'io-like', '>= 0.3.0'
  
  # for Qt
  depend_on 'qtbindings', '>=4.6.3'
  depend_on 'qtext', '>=0.6.7'
  
  depend_on 'test-unit', :development => true
  depend_on 'shoulda', :development => true
  depend_on 'faker', :development => true
  
  # for 1.8
  depend_on 'generator', :development => true

  # read file list from Manifest.txt
  gem.files File.new('Manifest.txt').to_a.map( &:chomp )

  # List of files to generate rdoc from
  # Not the same as the rdoc -i which is list of files
  # to search for include directives
  rdoc.include %w{README.txt ^lib/clevic/.*\.rb$ models/examples.rb History.txt TODO}
  
  # List of Regexs to exclude from rdoc processing
  rdoc.exclude %w{^pkg.*}
  
  # Include URL for git browser in rdoc output
  rdoc.opts %w{-W http://gitweb.semiosix.com/gitweb.cgi?p=clevic;a=blob;f=%s;hb=HEAD}

  rdoc.main 'README.txt'
  #~ rdoc.external true
end

  #~ p.clean_globs |= %w[**/.DS_Store tmp *.log]
  #~ path = (p.rubyforge_name == p.name) ? p.rubyforge_name : "\#{p.rubyforge_name}/\#{p.name}"
  #~ p.remote_rdoc_dir = File.join(path.gsub(/^#{p.rubyforge_name}\/?/,''), 'rdoc')
  #~ p.rsync_args = '-av --delete --ignore-errors'
#~ end

#~ Dir['tasks/**/*.rake'].each { |t| load t }
