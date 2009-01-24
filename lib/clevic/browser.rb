require 'clevic/search_dialog.rb'
require 'clevic/ui/browser_ui.rb'
require 'clevic/record.rb'
require 'clevic.rb'

module Clevic

=begin rdoc
The main application class. Display as many tabs as there are Clevic::Record or ActiveRecord::Base
subclasses. 
=end
class Browser < Qt::Widget
  slots *%w{dump() refresh_table() filter_by_current(bool) next_tab() previous_tab() current_changed(int)}
  
  def initialize( main_window )
    super( main_window )
    
    # do menus and widgets
    @layout = Ui::Browser.new
    @layout.setup_ui( main_window )
    
    # set icon. MUST come after call to setup_ui
    icon_path = Pathname.new( __FILE__ ).parent + "ui/icon.png"
    raise "icon.png not found" unless icon_path.file?
    main_window.window_icon = Qt::Icon.new( icon_path.realpath.to_s )
    
    # add the tables tab
    @tables_tab = Qt::TabWidget.new( @layout.main_widget )
    @layout.main_widget.layout.add_widget @tables_tab
    @tables_tab.tab_bar.focus_policy = Qt::NoFocus
    
    # hide the file menu, for now
    @layout.menubar.remove_action( @layout.menu_file.menu_action )
    
    # tab navigation
    @layout.action_next.connect       SIGNAL( 'triggered()' ),          &method( :next_tab )
    @layout.action_previous.connect   SIGNAL( 'triggered()' ),          &method( :previous_tab )

    # dump model for current tab
    @layout.action_dump.visible = $options[:debug]
    @layout.action_dump.connect       SIGNAL( 'triggered()' ),          &method( :dump )
    
    tables_tab.connect                SIGNAL( 'currentChanged(int)' ),  &method( :current_changed )
    
    load_models
    update_menus
    main_window.window_title = [database_name, 'Clevic'].compact.join ' '
  end
  
  # Set the main window title to the name of the database, if we can find it.
  def database_name
    "Fix This #{__FILE__}:#{__LINE__}"
    #~ table_view.model.entity_class.db_options.database
  end  
  
  def update_menus
    # update edit menu
    @layout.menu_edit.clear
    
    # do the model-specific menu items first
    table_view.model_actions.each do |action|
      @layout.menu_edit.add_action( action )
    end
    
    # now do the generic edit items
    table_view.edit_actions.each do |action|
      @layout.menu_edit.add_action( action )
    end
    
    # update search menu
    @layout.menu_search.clear
    table_view.search_actions.each do |action|
      @layout.menu_search.add_action( action )
    end
  end
  
  # activated by Ctrl-Shift-D for debugging
  def dump
    puts "table_view.model: #{table_view.model.inspect}"
    puts "table_view.model.entity_class: #{table_view.model.entity_class.inspect}"
  end
  
  # return the Clevic::TableView object in the currently displayed tab
  def table_view
    tables_tab.current_widget
  end
  
  def tables_tab
    @tables_tab
  end
  
  # slot to handle Ctrl-Tab and move to next tab, or wrap around
  def next_tab
    tables_tab.current_index = 
    if tables_tab.current_index >= tables_tab.count - 1
      0
    else
      tables_tab.current_index + 1
    end
  end

  # slot to handle Ctrl-Backtab and move to previous tab, or wrap around
  def previous_tab
    tables_tab.current_index = 
    if tables_tab.current_index <= 0
      tables_tab.count - 1
    else
      tables_tab.current_index - 1
    end
  end
  
  # slot to handle the currentChanged signal from tables_tab, and
  # set focus on the grid
  def current_changed( current_tab_index )
    update_menus
    tables_tab.current_widget.set_focus
  end
  
  # shortcut for the Qt translate call
  def translate( st )
    Qt::Application.translate("Browser", st, nil, Qt::Application::UnicodeUTF8)
  end

  # return the list of descendants of ActiveRecord::Base, or
  # of Clevic::Record
  def find_models
    models = []
    ObjectSpace.each_object( Class ) do |x|
      if x.ancestors.include?( ActiveRecord::Base )
        case
          when x == ActiveRecord::Base; # don't include this
          when x == Clevic::Record; # don't include this
          else; models << x
        end
      end
    end
    models.sort{|a,b| a.name <=> b.name}
  end
  
  # Create the tabs, each with a collection for a particular entity class.
  #
  # models parameter can be an array of Model objects, in order of display.
  # if models is nil, find_models is called
  def load_models
    models = Clevic::Record.models
    models = find_models if models.empty?
    Kernel.raise "no models to display" if models.empty?
    
    # Add all existing model objects as tabs, one each
    models.each do |model|
      unless model.entity_class.table_exists?
        puts "No table for #{model.entity_class.inspect}"
      end
        
      begin
        # create the the table_view and the table_model for the entity_class
        tab = 
        if model.entity_class.respond_to?( :ui )
          puts "Entity#ui deprecated. Use define_ui instead."
          model.ui( tables_tab )
        elsif model.respond_to?( :build_table_model )
          raise "Entity#build_table_model deprecated. Use define_ui instead."
        else
          Clevic::TableView.new( model, tables_tab )
        end
        
        # show status messages
        tab.connect( SIGNAL( 'status_text(QString)' ) ) { |msg| @layout.statusbar.show_message( msg, 10000 ) }
        
        # add a new tab
        tables_tab.add_tab( tab, translate( model.name.demodulize.tableize.humanize ) )
        
        # add the table to the Table menu
        action = Qt::Action.new( @layout.menu_model )
        action.text = translate( model.name.demodulize.tableize.humanize )
        action.connect SIGNAL( 'triggered()' ) do
          tables_tab.current_widget = tab
        end
        @layout.menu_model.add_action( action )
        
        # handle filter status changed, so we can provide a visual indication
        tab.connect SIGNAL( 'filter_status(bool)' ) do |status|
          # update the tab, so there's a visual indication of filtering
          tab_title = ( tab.filtered ? '| ' : '' ) + translate( entity_class.name.humanize )
          tables_tab.set_tab_text( tables_tab.current_index, tab_title )
        end
      rescue Exception => e
        puts
        puts e.backtrace #if $options[:debug]
        puts "UI from #{model} will not be available: #{e.message}"
      end
    end
  end
  
  # make sure all outstanding records are saved
  def save_all
    tables_tab.each {|x| x.save_row( x.current_index ) }
  end
end

end
