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
    
    @layout.tables_tab.connect      SIGNAL( 'currentChanged(int)' ),  &method( :current_changed )
    
    # as an example
    #~ @layout.tables_tab.connect SIGNAL( 'currentChanged(int)' ) { |index| puts "other current_changed: #{index}" }
  end
  
  # activated by Ctrl-D for debugging
  def dump
    widget = @layout.tables_tab.current_widget
    puts "widget.model: #{widget.model.inspect}" if widget.class == EntryTableView
  end
  
  def reload_model
    widget = @layout.tables_tab.current_widget
    #load "#{$options[:definition]}_models.rb"
    widget.reload_data
  end
  
  # toggle the filter, based on current selection if it's off
  def filter_by_current( bool_filter )
    widget = @layout.tables_tab.current_widget
    if bool_filter
      indexes = widget.selection_model.selected_indexes
      puts "indexes: #{indexes.inspect}"
      if indexes.empty?
        action_filter.checked = false
      end
      puts "indexes[0].attribute: #{indexes[0].attribute.inspect}"
      puts "indexes[0].attribute_value: #{indexes[0].attribute_value.inspect}"
      
      
      entity = indexes[0].entity
      column = entity.column_for_attribute( indexes[0].attribute )
      column ||= entity.column_for_attribute( indexes[0].attribute.to_s + "_id" )
      
      # TODO doesn't work for related tables
      widget.reload_data( :conditions => { column.name => entity.send( column.name ) } )
    else
      widget.reload_data( :conditions => {} )
    end
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
  
  def translate( st )
    Qt::Application.translate("Browser", st, nil, Qt::Application::UnicodeUTF8)
  end

  def find_models( models = $options[:models] )
    puts models.inspect
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
