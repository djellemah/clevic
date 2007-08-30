# The view class, implementing neat shortcuts and other pleasantness
class EntryTableView < Qt::TableView
  
  def initialize( *args )
    super
    horizontal_header.movable = true
  end
  
  def relational_delegate( attribute, options )
    col = model.attributes.index( attribute )
    delegate = RelationalDelegate.new( self, model.columns[col], options )
    set_item_delegate_for_column( col, delegate )
  end
  
  def delegate( attribute, delegate_class )
    col = model.attributes.index( attribute )
    delegate = delegate_class.new( self, attribute )
    set_item_delegate_for_column( col, delegate )
  end
  
  def last_row?
    current_index.row == model.row_count - 1
  end
  
  def last_cell?
    current_index.row == model.row_count - 1 && current_index.column == model.column_count - 1
  end
  
  def fix_row_padding( rows = 0..model.collection.size )
    # decrease padding
    section_size = vertical_header.minimum_section_size
    rows.each do |row|
      vertical_header.resize_section( row, section_size )
    end
  end
  
  def rowsInserted( parent, first, last )
    super
    fix_row_padding( first .. last )
  end

  # override this to allow row padding to be fixed
  def setModel( model )
    super
    fix_row_padding( 0 .. model.collection.size - 1 )
  end
  
  # and override this because the Qt bindings don't call
  # setModel otherwise
  def model=( model )
    setModel( model )
  end
  
  def keyPressEvent( event )
    case
    # on the last row, and down is pressed
    # add a new row
    when event.down? && last_row?
      model.add_new_item
      
    # on the right-bottom cell, and tab is pressed
    # then add a new row
    when event.tab? && last_cell?
      model.add_new_item
      
    # copy the value from the row one above  
    when event.ctrl? && event.apostrophe?
      if current_index.row > 0
        key = current_index.attribute
        previous_item = model.collection[current_index.row - 1]
        current_item = model.collection[current_index.row]
        current_item.send( "#{key}=", previous_item.send( key ) )
        dataChanged( current_index, current_index )
      end
      
    # copy the value from the previous row, one cell right
    when event.ctrl? && event.bracket_right?
      if current_index.row > 0 && current_index.column < model.column_count
        key = current_index.attribute
        previous_item = model.collection[current_index.row - 1]
        current_item = model.collection[current_index.row]
        current_item.send( "#{key}=", previous_item.send( model.attributes[ current_index.column + 1 ] ) )
        dataChanged( current_index, current_index )
      end
      
    # copy the value from the previous row, one cell left
    when event.ctrl? && event.bracket_left?
      if current_index.row > 0 && current_index.column > 0
        key = current_index.attribute
        previous_item = model.collection[current_index.row - 1]
        current_item = model.collection[current_index.row]
        current_item.send( "#{key}=", previous_item.send( model.attributes[ current_index.column - 1 ] ) )
        dataChanged( current_index, current_index )
      end
      
    # insert today's date in the current field
    when event.ctrl? && event.semicolon?
      key = current_index.attribute
      current_item = model.collection[current_index.row]
      current_item.send( "#{key}=", Time.now )
      dataChanged( current_index, current_index )
      
    # dump current record to stdout
    when event.ctrl? && event.d?
      puts model.collection[current_index.row].inspect
      
    # add new record and go to it
    when event.ctrl? && event.n?
      model.add_new_item
      new_row_index = model.index( model.collection.size - 1, 0 )
      self.current_index = new_row_index
    
    # handle deletion of entire rows
    when event.delete?
      # translate from ModelIndex objects to row indices
      rows = vertical_header.selection_model.selected_rows.map{|x| x.row}
      unless rows.empty?
        model.remove_rows( rows ) 
        #~ make sure no other handlers get this event
        return
      end
      
    else
      #~ puts event.inspect
    end
    super
  end
  
  # save record whenever its row is exited
  def currentChanged( current_index, previous_index )
    if current_index.row != previous_index.row
      #~ set_current_index( previous_index ) unless
      saved = model.save( previous_index )
      if !saved
        error_message = Qt::ErrorMessage.new( self )
        error_message.show_message( "Errors with record" )
        puts model.collection[previous_index.row].errors.join("\n")
        error_message.show
      end
    end
    super
  end
  
  # these are mostly to see what methods are overridable
  def itemDelegate( model_index = nil )
    puts "itemDelegate for #{model_index.inspect}"
  end

  def setItemDelegate( delegate )
    puts "setItemDelegate: #{delegate.inspect}"
    super( delegate )
  end
  
  def setIndexWidget( *args )
    puts "setIndexWidget: #{args.inspect}"
    super( args )
  end
  
  def indexWidget( *args )
    puts "indexWidget: #{args.inspect}"
    super( args )
  end
    
  def setIndexWidget( *args )
    puts "setIndexWidget: #{args.inspect}"
    super( args )
  end
  
  def sizeHintForRow( row_index )
    puts "sizeHintForRow: #{row_index}"
    super( row_index )
  end
end
