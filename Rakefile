require 'rubygems'
require 'rake/clean'
require 'hoe'
require 'lib/clevic/version.rb'
require 'pathname'

Hoe.new( 'clevic', Clevic::VERSION ) do |s|
	s.author     = "John Anderson"
	s.email      = "john at semiosix dot com"
end

# generate a _ui.rb filename from a .ui filename
def ui_rb_file( ui_file )
  ui_file.gsub( /\.ui$/, '_ui.rb' )
end

# list of .ui files
UI_FILES = FileList.new( 'lib/clevic/ui/*.ui' )
CLEAN.include( 'ChangeLog', 'lib/clevic/ui/*.rb' )

UI_FILES.each do |ui_file|
  # make tasks to generate _ui.rb files
  file ui_rb_file( ui_file ) => [ ui_file ] do |t|
    sh "rbuic4 #{t.prerequisites} -o #{t.name}" 
  end
  
  namespace :ui do
  # make tasks to start designer when the ui file is named
    desc "Start Qt designer with #{ui_file}"
    file Pathname.new(ui_file).basename.to_s.ext do |t|
      sh "designer #{ui_file}"
    end
  end
end

desc 'Generate all _ui.rb files'
task :rbuic => UI_FILES.map{|x| ui_rb_file( x ) }

namespace :ui do
  desc 'Start Qt designer with the argument, or all .ui files. '
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

desc "Runs Clevic in debug mode, with test databases"
task :run => :rbuic do |t|
  ARGV.shift()
  exec "ruby -w -Ilib bin/clevic -D #{ARGV.join(' ')}"
end

desc "Runs irb in this project's context"
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
  namespace 'irb' do
    task short_model( model_file ) do |t|
      ARGV.shift()
      ENV['RUBYLIB'] ||= '.'
      ENV['RUBYLIB'] += ":#{File.expand_path('.')}/lib"
      exec "irb -Ilib -rclevic -r#{model_file} -rclevic/db_options.rb"
    end
  end
  
  # generate runs
  desc "run clevic with #{model_file}"
  task short_model( model_file ) do |t|
    exec "ruby -w -Ilib bin/clevic -D #{model_file}"
  end
end

task :package => :rbuic
