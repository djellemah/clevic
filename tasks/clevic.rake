task :package => :ui

desc "Update ChangeLog from the SVN log"
task :changelog do |t|
  ARGV.shift
  exec "svn2cl --break-before-msg -o ChangeLog #{ARGV.join(' ')}"
end

# generate a _ui.rb filename from a .ui filename
def ui_rb_file( ui_file )
  ui_file.gsub( /\.ui$/, '_ui.rb' )
end

# list of .ui files
UI_FILES = FileList.new( 'lib/clevic/ui/*.ui' )
CLEAN.include( 'ChangeLog', 'coverage', 'profiling' )
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

desc "Runs Clevic in debug mode, with test databases"
task :debug => :ui do |t|
  ARGV.shift()
  exec "ruby -w -rdebug -Ilib bin/clevic -D #{ARGV.join(' ')}"
end

desc "irb in this project's context"
task :irb do |t|
  ARGV.shift()
  ENV['RUBYLIB'] ||= ''
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
      ARGV.shift() if ARGV[0] == '--'
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
      ARGV.shift() if ARGV[0] == '--'
      cmd = "ruby -Ilib bin/clevic -D #{model_file} #{ARGV.join(' ')}"
      puts "cmd: #{cmd.inspect}"
      exec cmd
    end
  end

  namespace :warn do
    desc "run clevic with #{model_file} and warnings on"
    task short_model( model_file )  => :ui do |t|
      ARGV.shift()
      exec "ruby -w -Ilib bin/clevic -D #{model_file} #{ARGV.join(' ')}"
    end
  end
end
