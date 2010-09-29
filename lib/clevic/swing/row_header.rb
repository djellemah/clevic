module Clevic

  class RowHeaderModel < javax.swing.table.AbstractTableModel
    # Need a Clevic::TableModel here because the underlying
    # connection isn't always the same instance. Because of
    # CacheTable#renew
    def initialize( table_model )
      super()
      @table_model = table_model
      
      # re-fire events
      table_model.add_table_model_listener do |event|
        fireTableChanged( event )
      end
    end
    
    # override TableModel method
    def getRowCount
      @table_model.getRowCount
    end
    
    # override TableModel method
    def getColumnCount
      1
    end

    # override TableModel method
    def getColumnName( column_index )
      "id"
    end
    
    def getColumnClass( column_index )
      java.lang.Object
    end

    def isCellEditable( row_index, column_index )
      false
    end
    
    def getValueAt( row_index, column_index )
      row_index+1
    end
    
    def id_value( row_index, column_index )
      if @table_model.collection.cached_at?( row_index )
        "#{row_index+1} [id=#{@table_model.collection[row_index].id}]"
      else
        row_index+1
      end
    end
    
    def setValueAt( value, row_index, column_index )
      raise "Can't set values in the row header"
    end
  end

  # TODO sort out focus loss from main table, and inability
  # for main table to get focus back when a cell editor is clicked
  # TODO sort out error/validation row colouring
  class RowHeader < javax.swing.JTable
    # this will add a row header to the passed table_view
    def initialize( table_view )
      @table_view = table_view
      super( RowHeaderModel.new( table_view.model ) )
      #~ self.show_grid = table_view.jtable.show_grid
      self.font = table_view.font
      self.grid_color = java.awt.Color::white
      
      # user header renderer for all cells
      set_default_renderer( java.lang.Object, table_header.default_renderer )
      
      # set the width
      column_model.column( 0 ).preferred_width = table_view.column_width( 0, "  #{row_count}" )
      
      # make sure the field label shows up
      # don't need it for now cos we're using the row number
      #~ table_view.set_corner( javax.swing.ScrollPaneConstants::UPPER_LEFT_CORNER, table_header )
      
      # insert into the row header side of the scrollpane
      table_view.row_header = javax.swing.JViewport.new.tap do |vp|
        vp.view = self
        # make sure size is passed along
        vp.preferred_size = preferred_size
      end
      
      self.request_focus_enabled = false
    end
    attr_reader :table_view
    
    # TODO use coloring code once I've done vertical header
    def headerData( section, orientation, role )
      value = 
      case role
        when qt_background_role
          if orientation == Qt::Vertical
            item = collection[section]
            case
              when !item.errors.empty?
                Qt::Color.new( 'orange' )
              when item.changed?
                Qt::Color.new( 'yellow' )
            end
          end
          
        else
          #~ puts "headerData section: #{section}, role: #{const_as_string(role)}" if $options[:debug]
          nil
      end
      
      return value.to_variant
    end
    
  end

end
