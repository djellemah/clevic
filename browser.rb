require 'ui/browser_ui.rb'
require 'entry_table_view.rb'
require 'active_record'
require 'active_record/dirty.rb'

class Browser < Qt::Widget
  slots 'dump()'

  def initialize( main_window )
    super( main_window )
    @layout = Ui::Browser.new
    @layout.setup_ui( main_window )
    self.connect( @layout.actionDump, SIGNAL('activated()'), self, SLOT('dump()') )
  end
  
  # activated by Ctrl-D for debugging
  def dump
    widget = @layout.tables_tab.current_widget
    puts "widget.model: #{widget.model.inspect}" if widget.class == EntryTableView
  end
  
  def translate( st )
    Qt::Application.translate("Browser", st, nil, Qt::Application::UnicodeUTF8)
  end

  def find_models
    if $options[:models].nil?
      models = []
      ObjectSpace.each_object( Class ) {|x| models << x if x.superclass == ActiveRecord::Base }
      models
    else
      $options[:models]
    end
  end
  
  def open( file = '' )
    # remove the tab that Qt Designer puts in
    @layout.tables_tab.clear
    
    # Add all existing model objects as tabs, one each
    find_models.each do |model|
      if model.respond_to?( :ui )
        tab = model.ui( @layout.tables_tab )
      else
        raise "Can't build ui for #{model.name}"
      end
      @layout.tables_tab.add_tab( tab, translate( model.name.humanize ) )
    end
  end
end

# fetch command line options
require 'optparse'

$options = {}
oparser = OptionParser.new
oparser.on( '-h', '--host HOST', 'RDBMS host', String ) { |o| $options[:host] = o }
oparser.on( '-u', '--user USERNAME', String ) { |o| $options[:user] = o }
oparser.on( '-p', '--pass PASSWORD', String ) { |o| $options[:password] = o }
oparser.on( '-t', '--table TABLE', 'Table to display', String ) { |o| $options[:table] = o }
oparser.on( '-d', '--database DATABASE', 'Database name', String ) { |o| $options[:database] = o }
oparser.on( '-D', '-v', '--debug' ) { |o| $options[:debug] = true }
oparser.on( '-h', '-?', '--help' ) do |o|
  puts oparser.to_s
  exit( 0 )
end

args = oparser.parse( ARGV )

if args.size > 0
  $options[:definition] = args.shift
  require "#{$options[:definition]}_models.rb"
end

app = Qt::Application.new( args )

if $options[:debug]
  puts $options.inspect
  puts args.inspect
  exit( 0 )
end

# set up defaults
# $options[:database] to be defined with the models
$options[:adapter]  ||= 'postgresql'
$options[:host] ||= 'localhost'
$options[:username] ||= 'panic'
$options[:password] ||= ''

# connect to the database
if !$options.has_key?( :database )
  raise "Please define $options[:database]"
end

ActiveRecord::Base.establish_connection( $options )

puts "using database #{ActiveRecord::Base.connection.raw_connection.db}" if $options[:debug]

# show UI
main_window = Qt::MainWindow.new
browser = Browser.new( main_window )
browser.open( 'dummy' )
main_window.show
app.exec
