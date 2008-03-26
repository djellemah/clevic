require 'clevic/search_dialog.rb'

=begin
  The main application class.
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
    puts "current_tab_widget.model: #{current_tab_widget.model.inspect}" if current_tab_widget.class == EntryTableView
  end
  
  def current_tab_widget
    @layout.tables_tab.current_widget
  end
  
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
  
  def reload_model
    current_tab_widget.reload_data
  end
  
  # toggle the filter, based on current selection if it's off
  def filter_by_current( bool_filter )
    save_entity = current_tab_widget.current_index.entity
    save_index = current_tab_widget.current_index
    save_region = current_tab_widget.visual_region_for_selection( current_tab_widget.selection_model.selection )
    puts "save_region: #{save_region.inspect}"
    if bool_filter
      # filter by current selection
      # TODO handle a multiple-selection
      indexes = current_tab_widget.selection_model.selected_indexes
      if indexes.empty?
        @layout.action_filter.checked = false
        return
      elsif indexes.size > 1
        puts "Can't do multiple selection filters yet"
        return
      end
      
      current_tab_widget.reload_data( :conditions => { indexes[0].field_name => indexes[0].field_value } )
    else
      # unfilter
      current_tab_widget.reload_data( :conditions => {} )
    end
    
    puts "current_tab_widget.horizontal_offset: #{current_tab_widget.horizontal_offset.inspect}"
    puts "current_tab_widget.vertical_offset: #{current_tab_widget.vertical_offset.inspect}"
    point = Qt::Point.new( current_tab_widget.horizontal_offset, current_tab_widget.vertical_offset )
    puts "current_tab_widget.index_at: #{current_tab_widget.index_at(point)}"
    
    rect = current_tab_widget.children_rect
    
    puts "rect: #{rect.inspect}"
    top_left_index = current_tab_widget.index_at(rect.top_left)
    puts "top_left_index: #{top_left_index.inspect}, #{top_left_index.entity.inspect}"
    bottom_right_index = current_tab_widget.index_at(rect.bottom_right)
    puts "bottom_right_index: #{bottom_right_index.inspect}, #{bottom_right_index.entity.inspect}"
    
    # search top_left to bottom_right_index for the previous id value
    #~ current_tab_widget.model.connect SLOT
    
    #~ row = nil
    #~ current_tab_widget.model.collection.each_with_index do |obj,i|
      #~ puts "obj: #{obj.inspect}"
      #~ row = i if obj.id == save_id
    #~ end
    #~ puts "row: #{row.inspect}"
    
    #~ if row != nil
      #~ index = current_tab_widget.create_index( row, save_index.column )
      #~ puts "index: #{index.inspect}"
      #~ current_tab_widget.current_index = index
    #~ end
    
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
    puts "current_tab_index: #{current_tab_index.inspect}"
    @layout.tables_tab.current_widget.setFocus
  end
  
  def translate( st )
    Qt::Application.translate("Browser", st, nil, Qt::Application::UnicodeUTF8)
  end

  def find_models( models = $options[:models] )
    if models.nil? || models.empty?
      models = []
      ObjectSpace.each_object( Class ) {|x| models << x if x.superclass == ActiveRecord::Base }
      models
    else
      models
    end
  end
  
  # models can be an array of Model objects, in order of display
  # if nil, find_models is called
  def open( *models )
    # remove the tab that Qt Designer puts in
    @layout.tables_tab.clear
    # make sure focus goes to first table
    @layout.tables_tab.tab_bar.focus_policy = Qt::NoFocus
    
    # Add all existing model objects as tabs, one each
    find_models( models ).each do |model|
      if model.respond_to?( :ui )
        tab = model.ui( @layout.tables_tab )
      else
        raise "Can't build ui for #{model.name}"
      end
      @layout.tables_tab.add_tab( tab, translate( model.name.humanize ) )
    end
  end
end
