require 'fastercsv'
require 'stringio'

require 'clevic/model_builder.rb'
require 'clevic/filter_command.rb'

module Clevic

# Various methods common to view classes
class TableView
  include ActionBuilder
  
  # the current filter command
  attr_accessor :filtered
  def filtered?; !@filtered.nil?; end
  
  # Called from the gui-framework adapter code in this class
  # arg is:
  # - an instance of Clevic::View
  # - an instance of TableModel
  def framework_init( arg, &block )
    # the model/entity_class/builder
    case 
      when arg.is_a?( TableModel )
        self.model = arg
        init_actions( arg.entity_view )
      
      when arg.is_a?( Clevic::View )
        model_builder = arg.define_ui
        model_builder.exec_ui_block( &block )
        
        # make sure the TableView has a fully-populated TableModel
        # self.model is necessary to invoke the GUI layer
        self.model = model_builder.build( self )
        self.object_name = arg.widget_name
        
        # connect data_changed signals for the entity_class to respond
        connect_view_signals( arg )
        
        init_actions( arg )
      
      else
        raise "Don't know what to do with #{arg.inspect}"
    end
  end
  
  attr_accessor :object_name
  
  def title
    @title ||= model.entity_view.title
  end
  
  # find the row index for the given field id (symbol)
  def field_column( field )
    raise "use model.field_column( field )"
  end
    
  # return menu actions for the model, or an empty array if there aren't any
  def model_actions
    @model_actions ||= []
  end
  
  # hook for the sanity_check_xxx methods
  # called for the actions set up by ActionBuilder
  # it just wraps the action block/method in a catch
  # block for :insane. Will also catch exceptions thrown in actions to make
  # core application more robust to model & view errors.
  def action_triggered( &block )
    catch :insane do
      yield
    end
    
  rescue Exception => e
    puts
    puts "#{model.entity_view.class.name}: #{e.message}"
    puts e.backtrace
  end
  
  
  # called from framework_init
  def init_actions( entity_view )
    # add model actions, if they're defined
    list( :model ) do |ab|
      entity_view.define_actions( self, ab )
      separator unless collect_actions.empty?
    end
    
    # list of actions in the edit menu
    list( :edit ) do
      action :action_save, '&Save', :shortcut => 'Ctrl+S', :method => :save_current_rows
      #~ action :action_cut, 'Cu&t', :shortcut => 'Ctrl+X', :method => :cut_current_selection
      action :action_copy, '&Copy', :shortcut => 'Ctrl+C', :method => :copy_current_selection
      action :action_paste, '&Paste', :shortcut => 'Ctrl+V', :method => :paste
      action :action_delete, '&Delete', :shortcut => 'Del', :method => :delete_selection
      separator
      action :action_ditto, 'D&itto', :shortcut => 'Ctrl+\'', :method => :ditto, :tool_tip => 'Copy same field from previous record'
      action :action_ditto_right, 'Ditto Ri&ght', :shortcut => 'Ctrl+]', :method => :ditto_right, :tool_tip => 'Copy field one to right from previous record'
      action :action_ditto_left, '&Ditto L&eft', :shortcut => 'Ctrl+[', :method => :ditto_left, :tool_tip => 'Copy field one to left from previous record'
      action :action_insert_date, 'Insert Date', :shortcut => 'Ctrl+;', :method => :insert_current_date
      action :action_open_editor, '&Open Editor', :shortcut => 'F4', :method => :open_editor
      separator
      action :action_row, 'New Ro&w', :shortcut => 'Ctrl+N', :method => :new_row
      action :action_refresh, '&Refresh', :shortcut => 'Ctrl+R', :method => :refresh
      action :action_delete_rows, 'Delete Rows', :shortcut => 'Ctrl+Delete', :method => :delete_rows
      
      if $options[:debug]
        action :action_dump, 'D&ump', :shortcut => 'Ctrl+Shift+D' do
          puts model.collection[current_index.row].inspect
        end
      end
    end
    
    separator
    
    # list of actions for search
    list( :search ) do
      action :action_find, '&Find', :shortcut => 'Ctrl+F', :method => :find
      action :action_find_next, 'Find &Next', :shortcut => 'Ctrl+G', :method => :find_next
      action :action_filter, 'Fil&ter', :checkable => true, :shortcut => 'Ctrl+L', :method => :filter_by_current
      action :action_highlight, '&Highlight', :visible => false, :shortcut => 'Ctrl+H'
    end
  end
  
  def clipboard
    # Clipboard will be a framework-specific class
    @clipboard = Clipboard.new
  end

  # copy current selection to clipboard as CSV
  # TODO add text/csv, text/tab-separated-values, text/html as well as text/plain
  def copy_current_selection
    clipboard.text = current_selection_csv
  end
  
  # return the current selection as csv
  def current_selection_csv
    buffer = StringIO.new
    selected_rows.each do |row|
      buffer << row.map {|index| index.edit_value }.to_csv
    end
    buffer.string
  end
  
  def sanity_check_ditto
    if current_index.row == 0
      emit_status_text( 'No previous record to copy.' )
      throw :insane
    end
  end
  
  def sanity_check_read_only
    if current_index.field.read_only?
      emit_status_text( 'Can\'t copy into read-only field.' )
    elsif current_index.entity.readonly?
      emit_status_text( 'Can\'t copy into read-only record.' )
    else
      sanity_check_read_only_table
      return
    end
    throw :insane
  end
  
  def sanity_check_read_only_table
    if model.read_only?
      emit_status_text( 'Can\'t modify a read-only table.' )
      throw :insane
    end
  end
  
  def ditto
    sanity_check_ditto
    sanity_check_read_only
    one_up_index = current_index.choppy { |i| i.row -= 1 }
    previous_value = one_up_index.attribute_value
    if current_index.attribute_value != previous_value
      current_index.attribute_value = previous_value
      model.data_changed( current_index )
    end
  end
  
  # from and to are ModelIndex instances. Throws :insane if
  # their fields don't have the same attribute_type.
  def sanity_check_types( from, to )
    unless from.field.attribute_type == to.field.attribute_type
      emit_status_text( 'Incompatible data' )
      throw :insane
    end
  end
  
  def ditto_right
    sanity_check_ditto
    sanity_check_read_only
    if current_index.column >= model.column_count - 1
      emit_status_text( 'No column to the right' )
    else
      one_up_right = current_index.choppy {|i| i.row -= 1; i.column += 1 }
      sanity_check_types( one_up_right, current_index )
      current_index.attribute_value = one_up_right.attribute_value
      model.data_changed( current_index )
    end
  end
  
  def ditto_left
    sanity_check_ditto
    sanity_check_read_only
    unless current_index.column > 0
      emit_status_text( 'No column to the left' )
    else
      one_up_left = current_index.choppy { |i| i.row -= 1; i.column -= 1 }
      sanity_check_types( one_up_left, current_index )
      current_index.attribute_value = one_up_left.attribute_value
      model.data_changed( current_index )
    end
  end
  
  def insert_current_date
    sanity_check_read_only
    current_index.attribute_value = Time.now
    model.data_changed( current_index )
  end
  
  def open_editor
    # tell the table to edit here
    edit( current_index )
    
    # tell the editing component to do full edit, eg if it's a combo
    # box to open the list.
    current_index.field.delegate.full_edit
  end
  
  # Add a new row and move to it, provided we're not in a read-only view.
  def new_row
    sanity_check_read_only_table
    model.add_new_item
    selection_model.clear
    self.current_index = model.create_index( model.row_count - 1, 0 )
  end
  
  # Delete the current selection. If it's a set of rows, just delete
  # them. If it's a rectangular selection, set the cells to nil.
  # TODO make sure all affected rows are saved.
  def delete_selection
    busy_cursor do
      begin
        sanity_check_read_only
        
        # TODO translate from ModelIndex objects to row indices
        puts "#{__FILE__}:#{__LINE__}:implement vertical_header for delete_selection"
        #~ rows = vertical_header.selection_model.selected_rows.map{|x| x.row}
        rows = []
        unless rows.empty?
          # header rows are selected, so delete them
          model.remove_rows( rows ) 
        else
          # otherwise various cells are selected, so delete the cells
          delete_cells
        end
      rescue
        show_error $!.message
      end
    end
  end
  
  def search_dialog
    @search_dialog ||= SearchDialog.new( self )
  end
  
  # display a search dialog, and find the entered text
  def find
    result = search_dialog.exec( current_index.display_value )
    
    busy_cursor do
      case
        when result.accepted?
          search( search_dialog )
        when result.rejected?
          puts "Don't search"
        else
          puts "unknown dialog result #{result}"
      end
    end
  end
  
  def find_next
    # yes, this must be an @ otherwise it lazy-creates
    # and will never be nil
    if @search_dialog.nil?
      emit_status_text( 'No previous find' )
    else
      busy_cursor do
        save_from_start = search_dialog.from_start?
        search_dialog.from_start = false
        search( search_dialog )
        search_dialog.from_start = save_from_start
      end
    end
  end
  
  # force a complete reload of the current tab's data
  def refresh
    busy_cursor do
      restore_entity do
        model.reload_data
      end
    end
  end
  
  # return an array of the current selection, or the
  # current index in an array if the selection is empty
  def selection_or_current
    indexes_or_current( selection_model.selected_indexes )
  end
  
  def selected_rows_or_current
    indexes_or_current( selection_model.row_indexes.map{|row| model.create_index( row, 0 ) } )
  end
  
  # alternative access for auto_size_column
  def auto_size_attribute( attribute, sample )
    auto_size_column( model.attributes.index( attribute ), sample )
  end
  
  # is current_index on the last row?
  def last_row?
    current_index.row == model.row_count - 1
  end
  
  # is current_index on the bottom_right cell?
  def last_cell?
    current_index.row == model.row_count - 1 && current_index.column == model.column_count - 1
  end

  # resize all fields based on heuristics rather
  # than iterating through the entire data model
  def resize_columns
    model.fields.each_with_index do |field, index|
      auto_size_column( index, field.sample )
    end
  end
  
  # copied from actionpack
  def pluralize(count, singular, plural = nil)
    "#{count || 0} " + ((count == 1 || count == '1') ? singular : (plural || singular.pluralize))
  end

  # ask the question in a dialog. If the user says yes, execute the block
  def delete_multiple_cells?( question = 'Are you sure you want to delete multiple cells?', &block )
    sanity_check_read_only
    
    # go ahead with delete if there's only 1 cell, or the user says OK
    delete_ok =
    if selection_model.selected_indexes.size > 1
      confirm_dialog( question, "Multiple Delete" ).accepted?
    else
      true
    end
    
    yield if delete_ok
  end
  
  # Ask if multiple cell delete is OK, then replace contents
  # of selected cells with nil.
  def delete_cells
    delete_multiple_cells? do
      cells_deleted = false
      
      # do delete
      selection_model.selected_indexes.each do |index|
        index.attribute_value = nil
        cells_deleted = true
      end
      
      # deletes were done, so call data_changed
      if cells_deleted
        # save affected rows
        selection_model.row_indexes.each do |row_index|
          save_row( model.create_index( row_index, 0 ) )
        end
        
        # emit data changed for all ranges
        selection_model.ranges.each do |selection_range|
          model.data_changed( selection_range )
        end
      end
    end
  end
  
  def delete_rows
    delete_multiple_cells?( "Are you sure you want to delete #{selection_model.row_indexes.size} rows?" ) do
      begin
        model.remove_rows( selection_model.row_indexes )
      rescue
        puts $!.message
        puts $!.backtrace
        show_error $!.message
      end
    end
  end
  
  # handle certain key combinations that aren't shortcuts
  # TODO what is returned from here?
  def handle_key_press( event )
    begin
      # call to entity class for shortcuts
      begin
        view_result = model.entity_view.notify_key_press( self, event, current_index )
        return view_result unless view_result.nil?
      rescue Exception => e
        puts e.backtrace
        show_error( "Error in shortcut handler for #{model.entity_view.name}: #{e.message}" )
      end
      
      # thrown by the sanity_check_xxx methods
      catch :insane do
        case
        # on the last row, and down is pressed
        # add a new row
        when event.down? && last_row?
          new_row
          
        # on the right-bottom cell, and tab is pressed
        # then add a new row
        when event.tab? && last_cell?
          new_row
          
        # add new record and go to it
        # TODO this is actually a shortcut
        when event.ctrl? && event.return?
          new_row
        
        else
          #~ puts event.inspect
        end
      end
    rescue Exception => e
      puts e.backtrace
      puts e.message
      show_error( "handle_key_press #{__FILE__}:#{__LINE__} error in #{current_index.attribute.to_s}: \"#{e.message}\"" )
    end
  end
  
  def save_current_rows
    selection_model.row_indexes.each do |row_index|
      save_row( model.create_index( row_index, 0 ) )
    end
  end
  
  # save the entity in the row of the given index
  # actually, model.save will check if the record
  # is really changed before writing to DB.
  def save_row( index )
    if !index.nil? && index.valid?
      saved = model.save( index )
      if !saved
        # construct error message(s)
        msg = index.entity.errors.map do |field, errors|
          abbr_value = trim_middle( index.entity.send(field) )
          "#{field} (#{abbr_value}) #{errors.join(',')}"
        end.join( "\n" )
        
        show_error( "#{index.rc} #{msg}", "Validation Errors" )
      end
      saved
    end
  end
  
  # save record whenever its row is exited
  # make this work with framework
  def currentChanged( current_index, previous_index )
    if previous_index.valid? && current_index.row != previous_index.row
      self.next_index = nil
      save_row( previous_index )
    end
    super
  end
  
  # toggle the filter, based on current selection.
  def filter_by_current( bool_filter )
    filter_by_indexes( selection_or_current )
  end
  
  def filter_by_options( args )
    filtered.undo if filtered?
    self.filtered = FilterCommand.new( self, [], args )
    emit_filter_status( filtered.doit )
  end
  
  # Save the current entity, do something, then restore
  # the cursor position to the entity if possible.
  # Return the result of the block.
  def restore_entity( &block )
    save_entity = current_index.entity
    unless save_entity.nil?
      save_entity.save if save_entity.changed?
      save_index = current_index
    end
    
    retval = yield
    
    # find the entity if possible
    select_entity( save_entity, save_index.column ) unless save_entity.nil?
    
    retval
  end

  # Filter by the value in the current index.
  # indexes is a collection of TableIndex instances
  def filter_by_indexes( indexes )
    case
      when filtered?
        # unfilter
        restore_entity do
          filtered.undo
          self.filtered = nil
          # update status bar
          emit_status_text( nil )
          emit_filter_status( false )
        end
        
      when indexes.empty?
        emit_status_text( "No field selected for filter" )
        
      when !indexes.first.field.filterable?
        emit_status_text( "Can't filter on #{indexes.first.field.label}" )
      
      when indexes.size > 1
        emit_status_text( "Can't do multiple selection filters yet" )
      
      when indexes.first.entity.new_record?
        emit_status_text( "Can't filter on a new row" )
        
      else
        self.filtered = FilterCommand.new( self, indexes, :conditions => { indexes.first.field_name => indexes.first.field_value } )
        # try to end up on the same entity, even after the filter
        restore_entity do
          emit_filter_status( filtered.doit )
        end
        # update status bar
        emit_status_text( filtered.status_message )
    end
    filtered?
  end
  
  # Move to the row for the given entity and the given column.
  # If column is a symbol,
  # field_column will be called to find the integer index.
  def select_entity( entity, column = nil )
    # sanity check that the entity can actually be found
    raise "entity is nil" if entity.nil?
    unless entity.is_a?( model.entity_class )
      raise "entity #{entity.class.name} does not match class #{model.entity_class.name}"
    end
    
    # find the row for the saved entity
    found_row = busy_cursor do
      model.collection.index_for_entity( entity )
    end
    
    # create a new index and move to it
    unless found_row.nil?
      column = model.field_column( column ) if column.is_a? Symbol
      selection_model.clear
      self.current_index = model.create_index( found_row, column || 0 )
    end
  end
  
  # search_criteria must respond to:
  # * search_text
  # * whole_words?
  # * direction ( :forward, :backward )
  # * from_start?
  def search( search_criteria )
    indexes = model.search( current_index, search_criteria )
    if indexes.size > 0
      emit_status_text( "Found #{search_criteria.search_text} at row #{indexes.first.row}" )
      selection_model.clear
      self.current_index = indexes.first
    else
      emit_status_text( "No match found for #{search_criteria.search_text}" )
    end
  end

  # find the TableView instance for the given entity_view
  # or entity_model. Return nil if no match found.
  # TODO doesn't really belong here because TableView will not always
  # be in a TabWidget context.
  unless instance_methods.include?( 'find_table_view' )
    def find_table_view( entity_model_or_view )
      raise "framework responsibility"
    end
  end
  
  # execute the block with the TableView instance
  # currently handling the entity_model_or_view.
  # Don't execute the block if nothing is found.
  # TODO doesn't really belong here because TableView will not always
  # be in a TabWidget context.
  unless instance_methods.include?( 'with_table_view' )
    def with_table_view( entity_model_or_view, &block )
      raise "framework responsibility"
    end
  end
  
  # make this window visible if it's in a TabWidget
  # TODO doesn't really belong here because TableView will not always
  # be in a TabWidget context.
  unless instance_methods.include?( 'raise_widget' )
    def raise_widget
      raise "framework responsibility"
    end
  end
  
  # set next_index for certain operations. Is only activated when
  # to_next_index is called.
  attr_accessor :next_index

protected
  
  # show a busy cursor, do the block, back to normal cursor
  # return value of block
  # TODO implement generic way of indicating framework responsibility
  # :busy_cursor
  
  # return either the set of indexes with all invalid indexes
  # remove, or the current selection.
  def indexes_or_current( indexes )
    retval =
    if indexes.empty?
      [ current_index ]
    else
      indexes
    end
    
    # strip out bad indexes, so other things don't have to check
    # can't use select because copying indexes causes an abort
    # ie retval.select{|x| x != nil && x.valid?}
    retval.reject!{|x| x.nil? || !x.valid?}
    # retval needed here because reject! returns nil if nothing was rejected
    retval
  end

  # move to next_index, if it's set
  def to_next_index
    if next_index
      self.current_index = next_index
      self.next_index = nil
    end
  end
end

require 'clevic/table_view_paste.rb'

end
