require 'rubygems'
require 'rake/clean'
require 'hoe'
require 'pathname'

require 'config/requirements'
require 'config/hoe' # setup Hoe + all gem configuration

Dir['tasks/**/*.rake'].each { |rake| load rake }

# generate a _ui.rb filename from a .ui filename
def ui_rb_file( ui_file )
  ui_file.gsub( /\.ui$/, '_ui.rb' )
end

# list of .ui files
UI_FILES = FileList.new( 'lib/clevic/ui/*.ui' )
CLEAN.include( 'ChangeLog' )
CLOBBER.include( 'ChangeLog', 'pkg', 'lib/clevic/ui/*_ui.rb' )

UI_FILES.each do |ui_file|
  # make tasks to generate _ui.rb files
  file ui_rb_file( ui_file ) => [ ui_file ] do |t|
    sh "rbuic4 #{t.prerequisites} -o #{t.name}" 
  end
  
  # make tasks to start designer when the ui file is named
  desc "Start Qt designer with #{ui_file}"
  namespace :ui do |n|
    task Pathname.new(ui_file).basename.to_s.ext do |t|
      sh "designer #{ui_file}"
    end
  end
end

desc 'Generate all _ui.rb files'
task :ui => UI_FILES.map{|x| ui_rb_file( x ) }

namespace :ui do
  desc 'Start Qt designer with the argument, or all .ui files.'
  task :design do |t|
    ARGV.shift()
    if ARGV.size == 0
      # start designer with all ui files
      sh "designer #{UI_FILES.join(' ')}"
    else
      # start designer with all files that match an argument
      sh "designer #{ ARGV.map{|x| UI_FILES.grep( /\/#{x}/ ) }.join(' ') }"
    end
    true
  end
end

desc "Runs Clevic in normal mode, with live database."
task :run => :ui do |t|
  ARGV.shift()
  exec "ruby -Ilib bin/clevic #{ARGV.join(' ')}"
end

desc "Runs Clevic in warning mode, with test databases and debug flag on"
task :sqlite => :ui do |t|
  ARGV.shift()
  exec "ruby -Ilib bin/clevic #{ARGV.join(' ')} times_sqlite_model.rb"
end

desc "Runs Clevic in debug mode, with test databases"
task :debug => :ui do |t|
  ARGV.shift()
  exec "ruby -w -rdebug -Ilib bin/clevic -D #{ARGV.join(' ')}"
end

desc "irb in this project's context"
task :irb do |t|
  ARGV.shift()
  ENV['RUBYLIB'] += ":#{File.expand_path('.')}/lib"
  exec "irb -Ilib -rclevic"
end

# generate tasks for all model definition files
MODELS_LIST = FileList.new( '**/*models.rb' )

def short_model( model_file )
  Pathname.new( model_file ).basename.to_s.gsub( /_models.rb/, '' )
end

MODELS_LIST.each do |model_file|
  # generate irb contexts
  desc "irb with #{model_file}"
  namespace :irb do
    task short_model( model_file ) do |t|
      ARGV.shift()
      ENV['RUBYLIB'] ||= '.'
      ENV['RUBYLIB'] += ":#{File.expand_path('.')}/lib"
      exec "irb -Ilib -rclevic -r#{model_file} -rclevic/db_options.rb"
    end
  end
  
  # generate runs
  namespace :run do
    desc "run clevic with #{model_file}"
    task short_model( model_file )  => :ui do |t|
      ARGV.shift()
      exec "ruby -w -Ilib bin/clevic -D #{model_file} #{ARGV.join(' ')}"
    end
  end
end

task :package => :ui

# redefine this from the Hoe-1.7.0 sources to use
# the jamis template.
Rake::RDocTask.new(:docs) do |rd|
  rd.main = "README.txt"
  rd.options << '-d' if RUBY_PLATFORM !~ /win32/ and `which dot` =~ /\/dot/ and not ENV['NODOT']
  rd.rdoc_dir = 'doc'
  rd.template = 'config/jamis.rb'
  files = $hoe.spec.files.grep($hoe.rdoc_pattern)
  files -= ['Manifest.txt']
  rd.rdoc_files.push(*files)

  title = "#{$hoe.name}-#{$hoe.version} Documentation"
  title = "#{$hoe.rubyforge_name}'s " + title if $hoe.rubyforge_name != $hoe.name

  rd.options << "-t #{title}"
end

desc "Update History.txt from the SVN log"
task :history do |t|
  ARGV.shift
  exec "svn2cl --break-before-msg -o History.txt #{ARGV.join(' ')}"
end
