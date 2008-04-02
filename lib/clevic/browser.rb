require 'clevic/search_dialog.rb'
require 'ui/browser_ui.rb'

=begin rdoc
The main application class. Each model for display should have a self.ui method
which returns a EntryTableView instance, usually in conjunction with
an EntryBuilder.

  EntryTableView.new( Entry, parent ).create_model.new( Entry, parent ).create_model
    .
    .
    .
  end
  
Model instances may also implement <tt>self.key_press_event( event, current_index, view )</tt>
and <tt>self.data_changed( top_left_index, bottom_right_index, view )</tt> methods so that
they can respond to editing events and do Neat Stuff.
=end
class Browser < Qt::Widget
  slots *%w{dump() reload_model() filter_by_current(bool) next_tab() previous_tab() current_changed(int)}
  
  def initialize( main_window )
    super( main_window )
    @layout = Ui::Browser.new
    @layout.setup_ui( main_window )
    
    # connect slots
    @layout.action_dump.connect       SIGNAL( 'triggered()' ),          &method( :dump )
    @layout.action_reload.connect     SIGNAL( 'triggered()' ),          &method( :reload_model )
    @layout.action_filter.connect     SIGNAL( 'triggered(bool)' ),      &method( :filter_by_current )
    @layout.action_next.connect       SIGNAL( 'triggered()' ),          &method( :next_tab )
    @layout.action_previous.connect   SIGNAL( 'triggered()' ),          &method( :previous_tab )
    @layout.action_find.connect       SIGNAL( 'triggered()' ),          &method( :find )
    @layout.action_find_next.connect  SIGNAL( 'triggered()' ),          &method( :find_next )
    tables_tab.connect                SIGNAL( 'currentChanged(int)' ),  &method( :current_changed )
    
    # as an example
    #~ tables_tab.connect SIGNAL( 'currentChanged(int)' ) { |index| puts "other current_changed: #{index}" }
  end
  
  # activated by Ctrl-D for debugging
  def dump
    puts "table_view.model: #{table_view.model.inspect}" if table_view.class == EntryTableView
  end
  
  # return the EntryTableView object in the currently displayed tab
  def table_view
    tables_tab.current_widget
  end
  
  def tables_tab
    @layout.tables_tab
  end
  
  # display a search dialog, and find the entered text
  def find
    @search_dialog ||= SearchDialog.new
    result = @search_dialog.exec
    
    override_cursor( Qt::BusyCursor ) do
      case result
        when Qt::Dialog::Accepted
          search_for = @search_dialog.search_text
          table_view.search( @search_dialog )
        when Qt::Dialog::Rejected
          puts "Don't search"
        else
          puts "unknown dialog code #{result}"
      end
    end
  end
  
  def find_next
    if @search_dialog.nil?
      @layout.statusbar.show_message( 'No previous find' )
    else
      save_from_start = @search_dialog.from_start?
      @search_dialog.from_start = false
      table_view.search( @search_dialog )
      @search_dialog.from_start = save_from_start
    end
  end
  
  # force a complete reload of the current tab's data
  def reload_model
    table_view.model.reload_data
  end
  
  # toggle the filter, based on current selection.
  def filter_by_current( bool_filter )
    # TODO if there's no selection, use the current index instead
    table_view.filter_by_indexes( table_view.selection_model.selected_indexes )
    
    # set the checkbox in the menu item
    @layout.action_filter.checked = table_view.filtered
    
    # update the tab, so there's a visual indication of filtering
    tab_title = table_view.filtered ? translate( '| ' + table_view.model_class.name.humanize ) : translate( table_view.model_class.name.humanize )
    tables_tab.setTabText( tables_tab.current_index, tab_title )
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
    @layout.action_filter.checked = table_view.filtered
  end
  
  # shortcut for the Qt translate call
  def translate( st )
    Qt::Application.translate("Browser", st, nil, Qt::Application::UnicodeUTF8)
  end

  # return the list of models in $options[:models] or find them
  # as descendants of ActiveRecord::Base
  def find_models( models = $options[:models] )
    if models.nil? || models.empty?
      models = []
      ObjectSpace.each_object( Class ) {|x| models << x if x.superclass == ActiveRecord::Base }
      models
    else
      models
    end
  end
  
  # Create the tabs, each with a collection for a particular model class.
  #
  # models parameter can be an array of Model objects, in order of display.
  # if models is nil, find_models is called
  def open( *models )
    models = $options[:models] if models.empty?
    # remove the tab that Qt Designer puts in
    tables_tab.clear
    # make sure focus goes to first table
    tables_tab.tab_bar.focus_policy = Qt::NoFocus
    
    # Add all existing model objects as tabs, one each
    find_models( models ).each do |model|
      if model.respond_to?( :ui )
        tab = model.ui( tables_tab )
        tab.connect( SIGNAL( 'status_text(QString)' ) ) { |msg| @layout.statusbar.show_message( msg, 20000 ) }
      else
        raise "Can't build ui for #{model.name}. Provide a self.ui method."
      end
      tables_tab.add_tab( tab, translate( model.name.humanize ) )
    end
  end
  
  # make sure all outstanding records are saved
  def save_all
    tables_tab.each {|x| x.save_row( x.current_index ) }
  end
end
