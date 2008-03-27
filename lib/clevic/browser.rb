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
    @layout.action_dump.connect     SIGNAL( 'triggered()' ),          &method( :dump )
    @layout.action_reload.connect   SIGNAL( 'triggered()' ),          &method( :reload_model )
    @layout.action_filter.connect   SIGNAL( 'triggered(bool)' ),      &method( :filter_by_current )
    @layout.action_next.connect     SIGNAL( 'triggered()' ),          &method( :next_tab )
    @layout.action_previous.connect SIGNAL( 'triggered()' ),          &method( :previous_tab )
    @layout.action_find.connect     SIGNAL( 'triggered()' ),          &method( :find )
    @layout.tables_tab.connect      SIGNAL( 'currentChanged(int)' ),  &method( :current_changed )
    
    # as an example
    #~ @layout.tables_tab.connect SIGNAL( 'currentChanged(int)' ) { |index| puts "other current_changed: #{index}" }
  end
  
  # activated by Ctrl-D for debugging
  def dump
    puts "table_view.model: #{table_view.model.inspect}" if table_view.class == EntryTableView
  end
  
  # return the EntryTableView object in the currently displayed tab
  def table_view
    @layout.tables_tab.current_widget
  end
  
  # display a search dialog, and find the entered text
  def find
    sd = SearchDialog.new
    result = sd.exec
    case result
      when Qt::Dialog::Accepted
        search_for = sd.layout.search_text.text
        @layout.tables_tab.current_widget.keyboard_search( search_for )
      when Qt::Dialog::Rejected
        puts "Don't search"
      else
        puts "unknown dialog code #{result}"
    end
  end
  
  # force a complete reload of the current tab's data
  def reload_model
    table_view.model.reload_data
  end
  
  # toggle the filter, based on current selection.
  def filter_by_current( bool_filter )
    save_entity = table_view.current_index.entity
    save_index = table_view.current_index
    
    if bool_filter
      # filter by current selection
      # TODO handle a multiple-selection
      indexes = table_view.selection_model.selected_indexes
      if indexes.empty?
        @layout.action_filter.checked = false
        return
      elsif indexes.size > 1
        puts "Can't do multiple selection filters yet"
        return
      end
      
      table_view.model.reload_data( :conditions => { indexes[0].field_name => indexes[0].field_value } )
    else
      # unfilter
      table_view.model.reload_data( :conditions => {} )
    end
    
    # find the row for the saved entity
    found_row = table_view.model.collection.index_for_entity( save_entity )
    
    # create a new index and move to it
    table_view.current_index = table_view.model.create_index( found_row, save_index.column )
  end
  
  # slot to handle Ctrl-Tab and move to next tab, or wrap around
  def next_tab
    @layout.tables_tab.current_index = 
    if @layout.tables_tab.current_index >= @layout.tables_tab.count - 1
      0
    else
      @layout.tables_tab.current_index + 1
    end
  end

  # slot to handle Ctrl-Backtab and move to previous tab, or wrap around
  def previous_tab
    @layout.tables_tab.current_index = 
    if @layout.tables_tab.current_index <= 0
      @layout.tables_tab.count - 1
    else
      @layout.tables_tab.current_index - 1
    end
  end
  
  # slot to handle the currentChanged signal from tables_tab, and
  # set focus on the grid
  def current_changed( current_tab_index )
    @layout.tables_tab.current_widget.setFocus
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
    @layout.tables_tab.clear
    # make sure focus goes to first table
    @layout.tables_tab.tab_bar.focus_policy = Qt::NoFocus
    
    # Add all existing model objects as tabs, one each
    find_models( models ).each do |model|
      if model.respond_to?( :ui )
        tab = model.ui( @layout.tables_tab )
      else
        raise "Can't build ui for #{model.name}. Provide a self.ui method."
      end
      @layout.tables_tab.add_tab( tab, translate( model.name.humanize ) )
    end
  end
end
