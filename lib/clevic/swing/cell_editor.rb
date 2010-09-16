module Clevic

# This is the glue class that interfaces with JTable's API
# There's usually only ever one of them for any given JTable, 
# so it's created once, and then re-used repeatedly.
# Must inherit from JComponent so that it gets focus
# when the editing starts
class CellEditor < javax.swing.JComponent
  include javax.swing.table.TableCellEditor
  
  def initialize( table_view )
    super()
    @table_view = table_view
    @listeners = []
  end
  
  attr_accessor :listeners
  attr_reader :index
  
  def delegate
    index.field.delegate
  end
  
  # override TableCellEditor methods
  # basically, initialize a component to send back to the JTable, and store
  # a bunch of state information
  def getTableCellEditorComponent(jtable, value, selected, row_index, column_index)
    # remember index for later. The delegate and the editor and the value
    # all come from it.
    @index = @table_view.model.create_index( row_index, column_index )
    
    # use the delegate's component. It actually comes from the index, which
    # is a bit weird. But anyway.
    delegate.entity = @index.entity
    # need self so combo boxes can get back here and stop editing when enter is pressed
    delegate.init_component( self )
    delegate.editor
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
    delegate.value
  end
  
  # Asks the editor if it can start editing using anEvent.
  def isCellEditable(event_object)
    true
  end
  
  # Removes a listener from the list that's notified
  def removeCellEditorListener(cell_editor_listener)
    listeners.delete cell_editor_listener
  end
  
  # Docs say not used, as of Java-1.2. But it is used. Not sure
  # what to do with it, really.
  def shouldSelectCell(event_object)
    true
  end
  
  # Tells the editor to stop editing and accept any partially edited value as the value of the editor
  # true if editing was stopped, false otherwise
  def stopCellEditing
    listeners.each do |listener|
      listener.editingStopped( change_event )
    end
    
    # can return false here if editing should not stop
    # for some reason, ie validation didn't succeed
    true
  rescue
    puts
    puts $!.backtrace
    puts "returning false from stopCellEditing"
    false
  end
end

end
