module Clevic

  # TODO Weirdness with deleting a row. Takes a long time to get back to user
  # TODO TextArea not working.
  # TODO make sure a click in the main table when a row selection is active selects the main table cell
  # TODO allow for clevic/table_view to access the row selection for deletes
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
      "row"
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

  # The JTable used to display a row header, and allow row selection.
  # Also handles highlighting rows for different states, eg validation errors
  # or unsaved.
  # TODO need to add exceptions thrown by a Model.save to the error list in the model
  class RowHeader < javax.swing.JTable
    # for reloading and ease of testing
    # should probably fix this in Kernel or Module or Class
    unless ancestors.include?( javax.swing.table.TableCellRenderer )
      include javax.swing.table.TableCellRenderer
    end
    
    # The Clevic::TableView instance
    attr_reader :table_view
    
    # this will add a row header to the passed table_view
    def initialize( table_view )
      @table_view = table_view
      super( RowHeaderModel.new( table_view.model ) )
      self.font = table_view.font
      self.grid_color = java.awt.Color::white
      
      # user header renderer for all cells
      set_default_renderer( java.lang.Object, table_header.default_renderer )
      
      # set the width
      column_width = table_view.column_width( 0, "  #{row_count}" )
      column_model.column( 0 ).preferred_width = column_width
      
      # This is a workaround either for OSX, or java-1.5.0_19-b02-306
      self.minimum_size = java.awt.Dimension.new( column_width, minimum_size.height )

      # put a count above the row number header
      @count_label = javax.swing.JLabel.new( row_count.to_s ).tap do |count_label|
        count_label.font = self.font
        count_label.horizontal_alignment = javax.swing.JComponent::CENTER_ALIGNMENT
        table_view.set_corner( javax.swing.ScrollPaneConstants::UPPER_LEFT_CORNER, count_label )
        
        # make sure count label is updated when the model changes
        model.add_table_model_listener do |event|
          count_label.text = row_count.to_s
        end
      end
      
      # insert into the row header side of the scrollpane
      table_view.row_header = javax.swing.JViewport.new.tap do |vp|
        vp.view = self
        # make sure size is passed along to viewport
        vp.preferred_size = preferred_size
      end
      
      row_selection_handlers
    end
    
    # Transfer row header selection to full row selections in the main
    # table. Also clear the row header selection if a main table
    # selection happens.
    def row_selection_handlers
      # add a selection listener to select data table rows
      selection_model.addListSelectionListener do |list_event|
        process_list_selection( list_event )
      end
      
      # selections in the main table must clear any selections
      # in the row header, ie self
      table_view.jtable.selection_model.addListSelectionListener do |event|
        selection_model.clear_selection unless row_header_selecting
      end
    end
    
    # guard to make sure changes to main table selection don't feed back.
    def row_header_selecting( &block )
      if block_given?
        begin
          @row_header_selecting = true
          yield
        ensure
          @row_header_selecting = false
        end
      else
        @row_header_selecting
      end
    end
    
    def process_list_selection( event )
      # tell the main table handler we're busy
      row_header_selecting do
        # clear main table selection and start again
        table_view.jtable.selection_model.clear_selection
        
        # select the whole row in main table. Subsequent row selections will also
        # select the whole row. What a broken API.
        table_view.jtable.setColumnSelectionInterval( table_view.model.fields.size-1, 0 )
        
        selected_rows.each do |row|
          table_view.jtable.selection_model.addSelectionInterval( row, row )
        end
        
        # make sure the keyboard focus is on the latest selected row
        table_view.jtable.selection_model.addSelectionInterval( selection_model.lead_selection_index, selection_model.lead_selection_index )
        
        # make sure main table gets focus again
        table_view.request_focus
      end
    end
    
    # return self so that getTableCellRendererComponent is called
    def getCellRenderer( row, column )
      self
    end
    
    # Implementation of TableCellRenderer
    # return renderer Component
    def getTableCellRendererComponent(jtable, value,is_selected,has_focus,row,column)
      item = table_view.model.collection[row]
      renderer = get_default_renderer( java.lang.Object ).getTableCellRendererComponent(jtable,value,is_selected,has_focus,row,column)
      
      case
      # there's a validation error
      when !item.errors.empty?
        renderer.background = java.awt.Color::orange
        renderer.opaque = true
        renderer.tool_tip_text = "validation errors"
      
      # record isn't saved yet
      when item.changed?
        renderer.background = java.awt.Color::yellow
        renderer.opaque = true
        renderer.tool_tip_text = "not saved"
      
      when is_selected
        renderer.background = javax.swing.UIManager.get 'Table.selectionBackground'
        renderer.tool_tip_text = "id=#{item.id}"
      
      else
        renderer.tool_tip_text = "id=#{item.id}"
        
      end
      
      renderer
    end

  end

end
