require 'fastercsv'

require 'clevic/swing/action_builder.rb'

require 'clevic/model_builder.rb'
require 'clevic/filter_command.rb'

module Clevic

def self.tahoma
  if @font.nil?
    found = java.awt.GraphicsEnvironment.local_graphics_environment.all_fonts.select {|f| f.font_name == "Tahoma"}.first
    @font = found.deriveFont( 13.0 )
  end
  @font
end

class CellRenderer < javax.swing.table.DefaultTableCellRenderer
  def initialize( table_view )
    super()
    @table_view = table_view
  end
  
  def getTableCellRendererComponent( table, value, isSelected, hasFocus, row_index, column_index )
    index = SwingTableIndex.new( table.model, row_index, column_index )
    component = super( table, index.display_value, isSelected, hasFocus, row_index, column_index )
    
    # set alignment
    component.horizontal_alignment =
    case index.field.alignment
      when :left; javax.swing.SwingConstants::LEFT
      when :right; javax.swing.SwingConstants::RIGHT
      when :centre, :center; javax.swing.SwingConstants::CENTER
      else javax.swing.SwingConstants::LEADING
    end
    
    # set text colour
    component.foreground = index.field.foreground_for( index.entity ) ||
    if index.field.read_only? || index.entity.andand.readonly? || @table_view.model.read_only?
      java.awt.Color.lightGray
    end
    
    # set tooltip
    component.tool_tip_text = index.tooltip
    
    component
  rescue
    puts $!.backtrace
    puts $!.message
    puts index.entity.inspect
    nil
  end
end

# The view class
# TODO hook into key presses, call handle_key_press
class TableView < javax.swing.JScrollPane
  # arg is:
  # - an instance of Clevic::View
  # - an instance of TableModel
  def initialize( arg, &block )
    @jtable = javax.swing.JTable.new
    @jtable.setDefaultRenderer( java.lang.Object, CellRenderer.new( self ) )
    @jtable.auto_resize_mode = javax.swing.JTable::AUTO_RESIZE_OFF
    @jtable.selection_mode = javax.swing.ListSelectionModel::MULTIPLE_INTERVAL_SELECTION
    @jtable.column_selection_allowed = true
    @jtable.cell_selection_enabled = true
    @jtable.font = Clevic.tahoma
    
    super( @jtable )
    
    framework_init( arg, &block )
  end
  
  attr_reader :jtable
  
  def connect_view_signals( entity_view )
    model.addTableModelListener do |table_model_event|
      begin
        puts "table changed event: #{table_model_event.inspect}"
        # pass changed events to view definitions
        return unless table_model_event.updated?
          
        top_left = SwingTableIndex.new( model, table_model_event.first_row, table_model_event.column )
        bottom_right = SwingTableIndex.new( model, table_model_event.last_row, table_model_event.column )
        entity_view.notify_data_changed( self, top_left, bottom_right )
      rescue Exception => e
        puts
        puts "#{model.entity_view.class.name}: #{e.message}"
        puts e.backtrace
      end
    end
  end
  
  # return a collection of collections of SwingTableIndex objects
  # indicating the indices of the current selection
  def selected_rows
    @jtable.selected_rows.map do |row_index|
      @jtable.selected_columns.map do |column_index|
        SwingTableIndex.new( model, row_index, column_index )
      end
    end
  end
  
  # copy current selection to clipboard as CSV
  # could also use a javax.activation.DataHandler
  # for a more sophisticated API
  # TODO use 	javaJVMLocalObjectMimeType 
  # file:///usr/share/doc/java-sdk-docs-1.6.0.10/html/api/java/awt/datatransfer/DataFlavor.html#javaJVMLocalObjectMimeType
  def copy_current_selection
    transferable = java.awt.datatransfer.StringSelection.new( current_selection_csv )
    clipboard = java.awt.Toolkit.default_toolkit.system_clipboard
    clipboard.setContents( transferable, transferable )
  end
  
  # TODO refactor with Clevic::TableView
  def paste
    # yes, this MUST be camelCase cos it's a field not a method
    df = java.awt.datatransfer.DataFlavor.stringFlavor
    # also system_selection
    cb = java.awt.Toolkit.default_toolkit.system_clipboard
    clipboard_value = cb.getData( df ).to_s
    puts "clipboard_value: #{clipboard_value.inspect}"
    
    sanity_check_read_only
    
    # remove trailing "\n" if there is one
    text = clipboard.text.chomp
    arr = FasterCSV.parse( text )
    
    # TODO what did this do?
    #~ selection_model.selected_indexes.
    return true if selection_model.selection.size != 1
    
    selected_index = selection_model.selected_indexes.first
    
    if selection_model.single_cell?
      # only one cell selected, so paste like a spreadsheet
      if text.empty?
        # just clear the current selection
        model.setData( selected_index, nil.to_variant )
      else
        paste_to_index( selected_index, arr )
      end
    else
      if arr.size == 1 && arr.first.size == 1
        # only one value to paste, and multiple selection, so
        # set all selected indexes to the value
        value = arr.first.first
        selection_model.selected_indexes.each do |index|
          set_model_data( index, value )
          # save records to db
          model.save( index )
        end
        
        # notify of changed data
        model.data_changed do |change|
          sorted = selection_model.selected_indexes.sort
          change.top_left = sorted.first
          change.bottom_right = sorted.last
        end
      else
        return true if selection_model.ranges.first.height != arr.size
        return true if selection_model.ranges.first.width != arr.first.size
        
        # size is the same, so do the paste
        paste_to_index( selected_index, arr )
      end
    end
  end
  
  # TODO display message in status bar, ie pass up to parent window
  def emit_status_text( msg )
  end
  
  # emit whether the view is filtered or not
  def emit_filter_status( bool )
  end
  
  def sanity_check_read_only
    if current_index.field.read_only?
      emit status_text( 'Can\'t copy into read-only field.' )
    elsif current_index.entity.readonly?
      emit status_text( 'Can\'t copy into read-only record.' )
    else
      sanity_check_read_only_table
      return
    end
    throw :insane
  end
  
  def sanity_check_read_only_table
    if model.read_only?
      emit status_text( 'Can\'t modify a read-only table.' )
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
      emit status_text( 'No column to the right' )
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
      emit status_text( 'No column to the left' )
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
    edit( current_index )
    delegate = item_delegate( current_index )
    delegate.full_edit
  end
  
  # Add a new row and move to it, provided we're not in a read-only view.
  def new_row
    sanity_check_read_only_table
    model.add_new_item
    new_row_index = model.index( model.row_count - 1, 0 )
    currentChanged( new_row_index, current_index )
    selection_model.clear
    self.current_index = new_row_index
  end
  
  # Delete the current selection. If it's a set of rows, just delete
  # them. If it's a rectangular selection, set the cells to nil.
  # TODO make sure all affected rows are saved.
  def delete_selection
    sanity_check_read_only

    # translate from ModelIndex objects to row indices
    rows = vertical_header.selection_model.selected_rows.map{|x| x.row}
    unless rows.empty?
      # header rows are selected, so delete them
      model.remove_rows( rows ) 
    else
      # otherwise various cells are selected, so delete the cells
      delete_cells
    end
  end
  
  # display a search dialog, and find the entered text
  def find
    @search_dialog ||= SearchDialog.new
    result = @search_dialog.exec( current_index.gui_value )
    
    busy_cursor do
      case
        when result.accepted?
          search_for = @search_dialog.search_text
          search( @search_dialog )
        when result.rejected?
          puts "Don't search"
        else
          puts "unknown dialog result #{result.inspect}"
      end
    end
  end
  
  def find_next
    if @search_dialog.nil?
      emit status_text( 'No previous find' )
    else
      busy_cursor do
        save_from_start = @search_dialog.from_start?
        @search_dialog.from_start = false
        search( @search_dialog )
        @search_dialog.from_start = save_from_start
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
    indexes_or_current( selection_model.row_indexes )
  end
  
  # set the size of the column from the sample
  def auto_size_column( col, sample )
    @jtable.column_model.column( col ).preferred_width = column_width( col, sample )
  end

  # calculate the size of the column from the string value of the data
  def column_width( col, data )
    @jtable.getFontMetrics( @jtable.font).stringWidth( data ) + 5
  end
  
  # TODO is this even used?
  def relational_delegate( attribute, options )
    col = model.attributes.index( attribute )
    delegate = RelationalDelegate.new( self, model.columns[col], options )
    set_item_delegate_for_column( col, delegate )
  end
  
  def delegate( attribute, delegate_class, options = nil )
    col = model.attributes.index( attribute )
    delegate = delegate_class.new( self, attribute, options )
    set_item_delegate_for_column( col, delegate )
  end
  
  # is current_index on the last row?
  def last_row?
    current_index.row == model.row_count - 1
  end
  
  # is current_index on the bottom_right cell?
  def last_cell?
    current_index.row == model.row_count - 1 && current_index.column == model.column_count - 1
  end
  
  # forward to @jtable
  def model=( model )
    @jtable.model = model
    resize_columns
  end
  
  def model
    @jtable.model
  end
  
  # resize all fields based on heuristics rather
  # than iterating through the entire data model
  def resize_columns
    model.fields.each_with_index do |field, index|
      auto_size_column( index, field.sample )
    end
  end
  
  def moveCursor( cursor_action, modifiers )
    # TODO use this as a preload indicator
    super
  end

  # copied from actionpack
  def pluralize(count, singular, plural = nil)
    "#{count || 0} " + ((count == 1 || count == '1') ? singular : (plural || singular.pluralize))
  end

  # Paste a CSV array to the index, replacing whatever is at that index
  # and whatever is at other indices matching the size of the pasted
  # csv array. Create new rows if there aren't enough.
  # TODO implement
  def paste_to_index( top_left_index, csv_arr )
    csv_arr.each_with_index do |row,row_index|
      # append row if we need one
      model.add_new_item if top_left_index.row + row_index >= model.row_count
      
      row.each_with_index do |field, field_index|
        unless top_left_index.column + field_index >= model.column_count
          # do paste
          cell_index = top_left_index.choppy {|i| i.row += row_index; i.column += field_index }
          model.setData( cell_index, field.to_variant, Qt::PasteRole )
        else
          emit status_text( "#{pluralize( top_left_index.column + field_index, 'column' )} for pasting data is too large. Truncating." )
        end
      end
      # save records to db
      model.save( top_left_index.choppy {|i| i.row += row_index; i.column = 0 } )
    end
    
    # make the gui refresh
    model.data_changed do |change|
      change.top_left = top_left_index
      change.bottom_right = top_left_index.choppy do |i|
        i.row += csv_arr.size - 1
        i.column += csv_arr.first.size - 1
      end
    end
    emit model.headerDataChanged( Qt::Vertical, top_left_index.row, top_left_index.row + csv_arr.size )
  end
  
  # ask the question in a dialog. If the user says yes, execute the block
  def delete_multiple_cells?( question = 'Are you sure you want to delete multiple cells?', &block )
    sanity_check_read_only
    
    # go ahead with delete if there's only 1 cell, or the user says OK
    delete_ok =
    if selection_model.selected_indexes.size > 1
      # confirmation message, until there are undos
      msg = Qt::MessageBox.new(
        Qt::MessageBox::Question,
        'Multiple Delete',
        question,
        Qt::MessageBox::Yes | Qt::MessageBox::No,
        self
      )
      msg.exec == Qt::MessageBox::Yes
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
        selection_model.row_indexes.each do |index|
          index.entity.save
        end
        
        # emit data changed for all ranges
        selection_model.selection.each do |selection_range|
          model.data_changed( selection_range )
        end
      end
    end
  end
  
  def delete_rows
    delete_multiple_cells?( 'Are you sure you want to delete multiple rows?' ) do
      model.remove_rows( selection_model.selected_indexes.map{|index| index.row} )
    end
  end
  
  
  def show_error( msg )
    raise NotImplementedError, msg
  end
  
  def selection_model
    SelectionModel.new( @jtable )
  end
  
  # move the cursor & selection to the specified table_index
  def current_index=( table_index )
    @jtable.selection_model.clear_selection
    @jtable.setColumnSelectionInterval( table_index.column, table_index.column )
    @jtable.setRowSelectionInterval( table_index.row, table_index.row )
  end
  
  # return a SwingTableIndex for the current cursor position
  def current_index
    model.create_index( @jtable.selected_row, @jtable.selected_column )
  end

  # show a busy cursor, do the block, back to normal cursor
  # return value of block
  def busy_cursor( &block )
    raise NotImplementedError
  end
  
  # collect actions for the popup menu
  def add_action( action )
    ( @context_actions ||= [] ) << action
  end
end

end
