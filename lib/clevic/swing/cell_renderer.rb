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
    component.foreground =
    case
    # read-only
    when index.field.read_only? || index.entity.andand.readonly? || @table_view.model.read_only?
      java.awt.Color.lightGray
    
    # errors
    when index.entity.errors.has_key?( index.field.id )
      java.awt.Color.red
    
    # whatever the view says
    else
      index.field.foreground_for( index.entity )
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

end
