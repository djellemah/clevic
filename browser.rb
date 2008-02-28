require 'ui/browser_ui.rb'
require 'entry_table_view.rb'
require 'accounts_models.rb'

class Browser < Qt::Widget
  slots 'dump()'

  def initialize( main_window )
    super( main_window )
    @layout = Ui::Browser.new
    @layout.setup_ui( main_window )
    self.connect( @layout.actionDump, SIGNAL('activated()'), self, SLOT('dump()') )
  end
  
  def dump
    widget = @layout.tables_tab.current_widget
    puts "widget.model: #{widget.model.inspect}"
  end
  
  def translate( st )
    Qt::Application.translate("Browser", st, nil, Qt::Application::UnicodeUTF8)
  end
  
  def open( file = '' )
    #~ puts "opening"
    #~ tables_tab.clear
    
    #~ puts "accounts"
    accounts_tab = Tables.accounts( @layout.tables_tab )
    accounts_tab.object_name = 'accounts'
    @layout.tables_tab.add_tab( accounts_tab, translate( 'Accounts' ) )
    puts "accounts_tab.model: #{accounts_tab.model.inspect}"
    
    #~ puts "entries"
    entries_tab = Tables.entries( @layout.tables_tab )
    entries_tab.object_name = 'entries'
    @layout.tables_tab.add_tab( entries_tab, translate( 'Entries' ) )
    puts "entries_tab.model: #{entries_tab.model.inspect}"
    
    #~ tables_tab.corner_widget = Qt::PushButton.new
  end
end

require 'optparse'

options = {}
oparser = OptionParser.new
oparser.on( '-h', '--host HOST', 'RDBMS host', String ) { |o| options[:host] = o }
oparser.on( '-u', '--user USERNAME', String ) { |o| options[:user] = o }
oparser.on( '-p', '--pass PASSWORD', String ) { |o| options[:password] = o }
oparser.on( '-t', '--table TABLE', 'Table to display', String ) { |o| options[:table] = o }
oparser.on( '-d', '--database DATABASE', 'Database name', String ) { |o| options[:database] = o }
oparser.on( '-D', '-v', '--debug' ) { |o| options[:debug] = true }
oparser.on( '-h', '-?', '--help' ) do |o|
  puts oparser.to_s
  exit( 0 )
end

args = oparser.parse( ARGV )

if args.size > 0
  options[:table] = args.shift
end

app = Qt::Application.new( args )

if options[:debug]
  puts options.inspect
  puts args.inspect
  exit( 0 )
end

# set up defaults
options[:adapter]  ||= 'postgresql'
options[:database] ||= 'accounts'
options[:host] ||= 'localhost'
options[:username] ||= 'panic'
options[:password] ||= ''
options[:table] ||= 'accounts'

# connect to the database
ActiveRecord::Base.establish_connection( options )

puts "using database #{ActiveRecord::Base.connection.raw_connection.db}"

main_window = Qt::MainWindow.new
browser = Browser.new( main_window )
browser.open
main_window.show
app.exec
