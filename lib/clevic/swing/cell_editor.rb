module Clevic

# This is the glue class that interfaces with JTable's API
# There's usually only ever one of them for any given JTable, 
# so it's created once, and then re-used repeatedly.
class CellEditor
  include javax.swing.table.TableCellEditor
  
  def initialize( table_view )
    @table_view = table_view
    @listeners = []
  end
  
  attr_accessor :listeners
  attr_reader :index
  
  def default_delegate!
    if index.field.delegate.nil?
      if index.field.type == :boolean
        index.field.delegate = TextDelegate.new( index.field )
      else
        index.field.delegate = TextDelegate.new( index.field )
      end
    end
    index.field.delegate
  end
  
  def delegate
    index.field.delegate || default_delegate!
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
    delegate.init_component
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
  
  # Returns true if the editing cell should be selected, false otherwise.
  def shouldSelectCell(event_object)
    # This is mostly a workaround for a JTable behaviour where a single-click
    # always opens a combo box *with* it's drop-down. I don't want that.
    # Once the editor is displayed in the cell, whatever controls it has
    # can be used to open it further if necessary.
    delegate.minimal_edit
    
    # yes, select the cell. Whatever that means.
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
  end
end

end
