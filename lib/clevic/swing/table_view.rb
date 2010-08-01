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
  
  def getTableCellRendererComponent( table, value, selected, has_focus, row_index, column_index )
    index = table.model.create_index( row_index, column_index )
    component = super( table, index.display_value, selected, has_focus, row_index, column_index )
    
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

class CellEditor
  include javax.swing.table.TableCellEditor
  
  def initialize( table_view )
    super()
    @table_view = table_view
    @listeners = []
  end
  
  attr_accessor :listeners
  
	def getTableCellEditorComponent(jtable, value, selected, row_index, column_index)
    puts "getTableCellEditorComponent selected: #{selected.inspect}"
    @index = @table_view.model.create_index( row_index, column_index )
    # use the delegate's component
    @editor = @index.field.delegate.component( @index.entity )
  end

  # Adds a listener to the list that's notified when the editor stops, or cancels editing.
  def addCellEditorListener(cell_editor_listener)
    listeners << cell_editor_listener
  end
  
  def change_event
    @change_event ||= javax.swing.event.ChangeEvent.new( self )
  end
  
  # Tells the editor to cancel editing and not accept any partially edited value.
  def cancelCellEditing
    listeners.each do |listener|
      listener.editingCancelled( change_event )
    end
  end
  
  # Returns the value contained in the editor.
  def getCellEditorValue
    # TODO this probably won't work for editable combos
    if @editor.editable?
      # get the editor's text field value
      @editor.editor.item
    else
      @editor.selected_item 
    end
  end
  
  # Asks the editor if it can start editing using anEvent.
  def isCellEditable(event_object)
    puts "editable? event_object: #{event_object.inspect}"
    true
  end
  
  # Removes a listener from the list that's notified
  def removeCellEditorListener(cell_editor_listener)
    listeners.delete cell_editor_listener
  end
  
  # Returns true if the editing cell should be selected, false otherwise.
  def shouldSelectCell(event_object)
    puts "select? event_object: #{event_object.inspect}"
    true
  end
  
  # Tells the editor to stop editing and accept any partially edited value as the value of the editor
  # true if editing was stopped, false otherwise
  def stopCellEditing
    listeners.each do |listener|
      listener.editingStopped( change_event )
    end
    # TODO can return false here if editing should not stop
    # for some reason, ie validation didn't succeed
    true
  end
end

class ClevicTable < javax.swing.JTable
  attr_accessor :table_view
  
  def processKeyBinding( key_stroke, key_event, condition, pressed )
    # don't auto-start if it's a Ctrl, or Alt-modified key
    # or a function key. Hopefully this doesn't get checked
    # for every single keystroke while editing - those should
    # be captured by the cell editor.
    if key_event.alt? || key_event.ctrl? || key_event.meta? || key_event.fx?
      put_client_property( "JTable.autoStartsEdit", false )
    end
    
    # do what JTable normally does with keys
    super
  ensure
    put_client_property( "JTable.autoStartsEdit", true )
  end

  # override to make things simpler
  def getCellEditor( row_index, column_index )
    index = table_view.model.create_index( row_index, column_index )
    if index.field.delegate.nil?
      # use the table's component
      super( row_index, column_index )
    else
      # use our component
      @cell_editor ||= CellEditor.new( self )
    end
  end
end

# The view class
class TableView < javax.swing.JScrollPane
  # arg is:
  # - an instance of Clevic::View
  # - an instance of TableModel
  def initialize( arg, &block )
    super( @jtable = ClevicTable.new )
    @jtable.table_view = self
    
    # seems like this MUST go after the super call (or maybe the
    # ClevicTable constructor), otherwise Swing throws an error
    # somewhere deep inside something. It's not clear right now.
    
    # This should theoretically close editors when focus is lost
    # saving whatever values are in there
    jtable.put_client_property( "terminateEditOnFocusLost", true )
    
    # no auto-resizing of columns
    jtable.auto_resize_mode = javax.swing.JTable::AUTO_RESIZE_OFF
    
    # selection of all kinds allowed
    jtable.selection_mode = javax.swing.ListSelectionModel::MULTIPLE_INTERVAL_SELECTION
    jtable.row_selection_allowed = true
    jtable.column_selection_allowed = true
    jtable.cell_selection_enabled = true
    
    # appearance
    jtable.font = Clevic.tahoma
    
    jtable.setDefaultRenderer( java.lang.Object, CellRenderer.new( self ) )

    framework_init( arg, &block )
    
    # this must go after framework_init, because it needs the actions
    # which are set up in there
    jtable.component_popup_menu = popup_menu
  end
  
  def popup_menu
    @popup_menu ||= javax.swing.JPopupMenu.new.tap do |menu|
      model_actions.each do |action|
        menu << action.clone.tap{|a| a.shortcut = nil}
      end
      
      # now do the generic edit items
      edit_actions.each do |action|
        menu << action.clone.tap{|a| a.shortcut = nil}
      end
      
      menu.pack
    end
  end
  
  attr_reader :jtable
  
  def connect_view_signals( entity_view )
    model.addTableModelListener do |table_model_event|
      begin
        puts "table changed event: #{table_model_event.inspect}"
        # pass changed events to view definitions
        return unless table_model_event.updated?
        
        # unlikely to be useful, and in fact causes a very very long
        # calculation
        return if table_model_event.all_rows?
          
        top_left = model.create_index( table_model_event.first_row, table_model_event.column )
        bottom_right = model.create_index( table_model_event.last_row, table_model_event.column )
        
        Kernel.print "#{__FILE__}:#{__LINE__}"
        puts "top_left: #{top_left.inspect}"
        Kernel.print "#{__FILE__}:#{__LINE__}"
        puts "bottom_right: #{bottom_right.inspect}"
        
        entity_view.notify_data_changed( self, top_left, bottom_right )
        
        raise "TODO: call currentChanged, or something like that?"
      rescue Exception => e
        puts "#{model.entity_view.class.name}: #{e.message}"
        puts e.backtrace
      end
    end
  end
  
  # kind-of override of requestFocus, but it will probably only
  # work from Ruby
  def request_focus
    @jtable.request_focus
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
  
  # called from the framework-independent part to edit a cell
  def edit( table_index )
    @jtable.edit_cell_at( table_index.row, table_index.column )
  end
  
  def delegate( table_index )
    table_index.field.delegate
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
  
  def status_text_listeners
    @status_text_listeners ||= Set.new
  end
  
  # If msg is provided, yield to stored block.
  # If block is provided, store it for later.
  def emit_status_text( msg = nil, &notifier_block )
    if block_given?
      status_text_listeners << notifier_block
    else
      status_text_listeners.each do |notify|
        notify.call( msg )
      end
    end
  end
  
  def filter_status_listeners
    @filter_status_listeners ||= Set.new
  end
  
  # emit whether the view is filtered or not
  def emit_filter_status( bool = nil, &notifier_block )
    if block_given?
      filter_status_listeners << notifier_block
    else
      filter_status_listeners.each do |notify|
        notify.call( bool )
      end
    end
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
  
  def search_dialog
    raise NotImplementedError
  end
  
  def confirm_dialog( question, title )
    cd = ConfirmDialog.new do |dialog|
      dialog.parent = self
      dialog.question = question
      dialog.title = title
      dialog['Ok'] = :accept, :default
      dialog['Cancel'] = :reject
    end
    cd.show
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
  
  def show_error( msg )
    raise NotImplementedError, msg
  end
  
  def selection_model
    SelectionModel.new( self )
  end
  
  # move the cursor & selection to the specified table_index
  def current_index=( table_index )
    @jtable.selection_model.clear_selection
    @jtable.setColumnSelectionInterval( table_index.column, table_index.column )
    @jtable.setRowSelectionInterval( table_index.row, table_index.row )
    
    column_width = @jtable.column_model.getColumn( table_index.column ).width
    rect = java.awt.Rectangle.new( column_width * table_index.column, @jtable.row_height * table_index.row, column_width, @jtable.row_height )
    @jtable.scrollRectToVisible( rect )
  end
  
  # return a SwingTableIndex for the current cursor position
  # TODO optimise so we don't keep creating a new index, only if a selection
  # changed event has occurred
  def current_index
    model.create_index( @jtable.selected_row, @jtable.selected_column )
  end

  def wait_cursor
    @wait_cursor ||= java.awt.Cursor.new( java.awt.Cursor::WAIT_CURSOR )
  end
  
  # show a busy cursor, do the block, back to normal cursor
  # return value of block
  def busy_cursor( &block )
    save_cursor = cursor
    self.cursor = wait_cursor
    rv = yield
  ensure
    self.cursor = save_cursor
    rv
  end
  
  # collect actions for the popup menu
  def add_action( action )
    ( @context_actions ||= [] ) << action
  end
end

end
