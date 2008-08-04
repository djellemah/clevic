require 'clevic/search_dialog.rb'
require 'clevic/ui/browser_ui.rb'

module Clevic

=begin rdoc
The main application class. Each model for display should have a self.ui method
which returns a Clevic::TableView instance, usually in conjunction with
a ModelBuilder.

  Clevic::TableView.new( Entry, parent ).create_model.new( Entry, parent ).create_model
    .
    .
    .
  end
  
Model instances may also implement <tt>self.key_press_event( event, current_index, view )</tt>
and <tt>self.data_changed( top_left_index, bottom_right_index, view )</tt> methods so that
they can respond to editing events and do Neat Stuff.
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
  end
  
  def update_menus
    @layout.menu_edit.clear
    table_view.model_actions.each do |action|
      @layout.menu_edit.add_action( action )
    end
    unless table_view.model_actions.empty?
      @layout.menu_edit.add_action( Qt::Action.construct_exec(table_view) { setSeparator true } )
    end
    table_view.edit_actions.each do |action|
      @layout.menu_edit.add_action( action )
    end
    
    @layout.menu_search.clear
    table_view.search_actions.each do |action|
      @layout.menu_search.add_action( action )
    end
  end
  
  # activated by Ctrl-Shift-D for debugging
  def dump
    puts "table_view.model: #{table_view.model.inspect}"
    puts "table_view.model.model_class: #{table_view.model.model_class.inspect}"
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
    tables_tab.current_widget.setFocus
    
    update_menus
  end
  
  # shortcut for the Qt translate call
  def translate( st )
    Qt::Application.translate("Browser", st, nil, Qt::Application::UnicodeUTF8)
  end

  # return the list of descendants of ActiveRecord::Base
  def find_models
    models = []
    ObjectSpace.each_object( Class ) {|x| models << x if x.ancestors.include?( Clevic::Record ) }
    models
  end
  
  # define a default ui with plain fields for all
  # columns (except id) in the model. Could combine this with
  # DrySQL to automate the process.
  def define_default_ui( model )
    reflections = model.reflections.keys.map{|x| x.to_s}
    ui_columns = model.columns.reject{|x| x.name == 'id' }.map do |column|
      # TODO there must be a better way to do this
      att = column.name.gsub( '_id', '' )
      if reflections.include?( att )
        att
      else
        column.name
      end
    end
    
    Clevic::TableView.new( model, tables_tab ).create_model do
      ui_columns.each do |column|
        if model.reflections.has_key?( column.to_sym )
          relational column.to_sym
        else
          plain column.to_sym
        end
      end
      records :order => 'id'
    end
  end
  
  # Create the tabs, each with a collection for a particular model class.
  #
  # models parameter can be an array of Model objects, in order of display.
  # if models is nil, find_models is called
  def load_models
    models = Clevic::Record.models || find_models
    
    # Add all existing model objects as tabs, one each
    models.each do |model|
      tab = 
      if model.respond_to?( :ui )
        model.ui( tables_tab )
      else
        define_default_ui( model )
      end
      tab.connect( SIGNAL( 'status_text(QString)' ) ) { |msg| @layout.statusbar.show_message( msg, 20000 ) }
      tables_tab.add_tab( tab, translate( model.name.humanize ) )
      
      # handle filter status changed
      tab.connect SIGNAL( 'filter_status(bool)' ) do |status|
        # update the tab, so there's a visual indication of filtering
        tab_title = tab.filtered ? translate( '| ' + tab.model_class.name.humanize ) : translate( tab.model_class.name.humanize )
        tables_tab.set_tab_text( tables_tab.current_index, tab_title )
      end
      
    end
  end
  
  # make sure all outstanding records are saved
  def save_all
    tables_tab.each {|x| x.save_row( x.current_index ) }
  end
end

end
