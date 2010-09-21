require 'fastercsv'

require 'clevic/swing/action_builder.rb'
require 'clevic/swing/cell_editor.rb'

require 'clevic/model_builder.rb'
require 'clevic/filter_command.rb'

module Clevic

class CellRenderer < javax.swing.table.DefaultTableCellRenderer
  def initialize( table_view )
    super()
    @table_view = table_view
  end
  
  def getTableCellRendererComponent( table, value, selected, has_focus, row_index, column_index )
    index = table.model.create_index( row_index, column_index )
    component = super( table, index.display_value, selected, has_focus, row_index, column_index )
    
    # set alignment
    component.horizontal_alignment = index.field.swing_alignment
    
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

# TODO make sure JTable doesn't grab Ctrl-C and do its own copy routine.
# TODO make sure Delegates use the correct copy routines.
# TODO make sure Ctrl-V uses TableView paste routine
class ClevicTable < javax.swing.JTable
  attr_accessor :table_view
  
  def processKeyBinding( key_stroke, key_event, condition, pressed )
    # don't auto-start if it's a Ctrl, or Alt-modified key
    # or a function key. Hopefully this doesn't get checked
    # for every single keystroke while editing - those should
    # be captured by the cell editor.
    if key_event.alt? || key_event.ctrl? || key_event.meta? || key_event.fx? || key_event.del? || key_event.esc?
      put_client_property( "JTable.autoStartsEdit", false )
    end
    
    # do what JTable normally does with keys
    super
  rescue Exception => e
    table_view.model.emit_data_error( table_view.current_index, nil, e.message )
  ensure
    put_client_property( "JTable.autoStartsEdit", true )
  end

  # override to make things simpler
  def getCellEditor( row_index, column_index )
    index = table_view.model.create_index( row_index, column_index )
    
    # Basically, this is for boolean editing. Number of mouse
    # clicks and so on is horribly complicated, so just let the
    # code in javax.swing.whatever handle it.
    # It has to go here and not in CellEditor, otherwise
    # listeners and things are wrong.
    if data_class = index.field.delegate.native
      # use the default editor for this class of object
      getDefaultEditor( data_class )
    else
      # use the Clevic CellEditor
      @cell_editor ||= CellEditor.new( self )
    end
  rescue
    puts "#{__FILE__}:#{__LINE__}:$!.message: #{$!.message}"
    puts $!.backtrace
    puts index.entity.inspect
    nil
  end

  # for mouse events, only edit if the cell is
  # already selected provided it isn't a combo
  # box, in which case show the drop-down arrow, but
  # not the drop-down itself.
  def editCellAt( row, column, event = nil )
    if event
      index = table_view.model.create_index(row,column)
      edit_ok =
      if event.is_a?( java.awt.event.MouseEvent ) && index.field.delegate.needs_pre_selection?
        # the table_view selection model is mine. The JTable one is not.
        # Maybe that's weird.
        table_view.selection_model.with do |sm|
          sm.single_cell? && sm.selected?( row, column )
        end
      else
        true
      end
      
      # must call superclass here to do the edit rather than
      # just returning whether it should be edited. Java. tsk tsk.
      if edit_ok
        super
      else
        false
      end
    else
      # no event, so do whatever JTable does, which seems to work OK.
      super
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
    
    # cell editors get focus immediately on editor start
    jtable.surrendersFocusOnKeystroke = true
    
    # no auto-resizing of columns
    jtable.auto_resize_mode = javax.swing.JTable::AUTO_RESIZE_OFF
    
    # selection of all kinds allowed
    jtable.selection_mode = javax.swing.ListSelectionModel::MULTIPLE_INTERVAL_SELECTION
    jtable.row_selection_allowed = true
    jtable.column_selection_allowed = true
    jtable.cell_selection_enabled = true
    
    # appearance
    jtable.font = Clevic.tahoma
    self.font = Clevic.tahoma
    
    jtable.setDefaultRenderer( java.lang.Object, CellRenderer.new( self ) )
    
    fix_input_map
    
    framework_init( arg, &block )
    
    # this must go after framework_init, because it needs the actions
    # which are set up in there
    jtable.component_popup_menu = popup_menu
  end
  
  class EmptyAction < javax.swing.AbstractAction
    def actionPerformed( action_event ); end
  end
  
  def empty_action
    @empty_action ||= EmptyAction.new
  end
  
  def add_map( key_string, action = empty_action )
    map.put( javax.swing.KeyStroke.getKeyStroke( key_string ), action )
  end
  
  def map
    @map ||= jtable.getInputMap( javax.swing.JComponent::WHEN_ANCESTOR_OF_FOCUSED_COMPONENT )
  end
  
  # This puts empty actions in the local keyboard map so that the
  # generic keyboard map doesn't catch them and prevent our menu actions
  # from being triggered
  # TODO I'm sure this isn't the right way to do this.
  def fix_input_map
    add_map 'ctrl pressed C'
    add_map 'ctrl pressed V'
    add_map 'meta pressed V'
    add_map 'ctrl pressed X'
    add_map 'pressed DEL'
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
    # pick up model changes and pass them to the Clevic::View object
    model.addTableModelListener do |table_model_event|
      begin
        # pass changed events to view definitions
        return unless table_model_event.updated?
        
        # unlikely to be useful to models, and in fact causes a very very long
        # calculation. So don't pass it on.
        return if table_model_event.all_rows?
          
        top_left = model.create_index( table_model_event.first_row, table_model_event.column )
        bottom_right = model.create_index( table_model_event.last_row, table_model_event.column )
        
        entity_view.notify_data_changed( self, top_left, bottom_right )
        
        to_next_index
      rescue Exception => e
        show_error e.message
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
    # TODO keyboard focus doesn't seem to be reassigned to combo
    # when editing is started this way.
    @jtable.editCellAt( table_index.row, table_index.column )
  end
  
  # copy current selection to clipboard as CSV
  # could also use a javax.activation.DataHandler
  # for a more sophisticated API
  # TODO use 	javaJVMLocalObjectMimeType 
  # file:///usr/share/doc/java-sdk-docs-1.6.0.10/html/api/java/awt/datatransfer/DataFlavor.html#javaJVMLocalObjectMimeType
  # also use a DataFlavor with mimetype application/x-java-serialized-object
  # to transfer between cells.
  def copy_current_selection
    transferable = java.awt.datatransfer.StringSelection.new( current_selection_csv )
    clipboard = java.awt.Toolkit.default_toolkit.system_clipboard
    clipboard.setContents( transferable, transferable )
  end
  
  def read_clipboard
    java.awt.Toolkit.default_toolkit.system_clipboard.getData( java.awt.datatransfer.DataFlavor.stringFlavor ).to_s
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
  
  # set the size of the column from the sample
  def auto_size_column( col, sample )
    @jtable.column_model.column( col ).preferred_width = column_width( col, sample )
  end

  # calculate the size of the column from the string value of the data
  def column_width( col, data )
    @jtable.getFontMetrics( @jtable.font).stringWidth( data ) + 5
  end
  
  # forward to @jtable
  # also handle model#emit_data_error
  def model=( model )
    emitter_block = lambda do |index,value,message|
      emit_status_text "#{message}: #{value}"
    end
    @jtable.model.remove_data_error( &emitter_block ) if @jtable.model.respond_to? :remove_data_error
    @jtable.model = model
    @jtable.model.emit_data_error( &emitter_block ) if @jtable.model.respond_to? :emit_data_error
    resize_columns
  end
  
  def model
    @jtable.model
  end
  
  def show_error( msg )
    emit_status_text msg
  end
  
  def selection_model
    SelectionModel.new( self )
  end
  
  # move the cursor & selection to the specified table_index
  def current_index=( table_index )
    @jtable.selection_model.clear_selection
    @jtable.setColumnSelectionInterval( table_index.column, table_index.column )
    @jtable.setRowSelectionInterval( table_index.row, table_index.row )
    
    # x position. Should be sum of widths of all columns up to the beginning of this one
    # ie not including this one, hence the -1
    xpos = (0..table_index.column-1).inject(0) do |sum,column_index|
      sum + @jtable.column_model.getColumn( column_index ).width
    end
    
    rect = java.awt.Rectangle.new(
      xpos,
      
      # y position
      @jtable.row_height * table_index.row,
      
      # width of this column
      @jtable.column_model.getColumn( table_index.column ).width,
      
      # height
      @jtable.row_height
    )
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
