require 'entry_builder.rb'

# The view class, implementing neat shortcuts and other pleasantness
class EntryTableView < Qt::TableView
  attr_reader :model_class
  
  def initialize( model_class, *args )
    @model_class = model_class
    super()
    horizontal_header.movable = true
    sorting_enabled = true
    # turn off "Object#type deprecated" messages
    $VERBOSE=nil
  end
  
  def auto_size_attribute( attribute, sample )
    col = model.attributes.index( attribute )
    self.set_column_width( col, column_size( col, sample ).width )
  end
  
  def auto_size_column( col, sample )
    self.set_column_width( col, column_size( col, sample ).width )
  end

  # mostly copied from qheaderview.cpp:2301
  def column_size( col, data )
    opt = Qt::StyleOptionHeader.new
    #~ initStyleOption(&opt);
    
    # fetch font size
    fnt = font
    #~ fnt.bold = true
    opt.fontMetrics = Qt::FontMetrics.new( fnt )
    
    # set data 
    opt.text = data.to_s
    
    # icon size. Not needed
    #~ variant = d->model->headerData(logicalIndex, d->orientation, Qt::DecorationRole);
    #~ opt.icon = qvariant_cast<QIcon>(variant);
    #~ if (opt.icon.isNull())
        #~ opt.icon = qvariant_cast<QPixmap>(variant);
    
    size = Qt::Size.new( 100, 30 )
    # final parameter could be header section
    style.sizeFromContents( Qt::Style::CT_HeaderSection, opt, size );
  end
  
  def create_model( &block )
    @builder = EntryBuilder.new( self )
    yield( @builder )
    @builder.build
    self
  end
  
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
    
    model.connect( SIGNAL( 'data_error(QModelIndex, QVariant, QString)' ) ) do |index,variant,msg|
      error_message = Qt::ErrorMessage.new( self )
      error_message.show_message( "Incorrect value '#{variant.value}' entered for field [#{index.attribute.to_s}].\nMessage was: #{msg}" )
      error_message.show
    end
  end
  
  # and override this because the Qt bindings don't call
  # setModel otherwise
  def model=( model )
    setModel( model )
    resize
  end
  
  # resize all fields based on heuristics rather
  # than iterating through the entire data model
  def resize
    @builder.fields.each_with_index do |field, index|
      auto_size_column( index, field.sample )
    end
  end
  
  def keyPressEvent( event )
    # for some reason, trying to call another method inside
    # the being .. rescue block throws a superclass method not
    # found error. Weird.
    begin
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
        
      # f4 should open editor immediately
      when event.f4?
        edit( current_index, Qt::AbstractItemView::AllEditTriggers, event )
        delegate = item_delegate( current_index )
        delegate.open
        
      else
        #~ puts event.inspect
      end
      super
    rescue Exception => e
      puts e.backtrace.join( "\n" )
      error_message = Qt::ErrorMessage.new( self )
      error_message.show_message( "Error in #{current_index.attribute.to_s}: \"#{e.message}\"" )
      error_message.show
    end
  end
  
  # save record whenever its row is exited
  def currentChanged( current_index, previous_index )
    if current_index.row != previous_index.row
      #~ set_current_index( previous_index ) unless
      saved = model.save( previous_index )
      if !saved
        error_message = Qt::ErrorMessage.new( self )
        msg = model.collection[previous_index.row].errors.join("\n")
        error_message.show_message( msg )
        error_message.show
      end
    end
    super
  end
  
  # prevent tab pressed from editing next field
  def closeEditor( editor, end_edit_hint )
    case end_edit_hint
      when Qt::AbstractItemDelegate.EditNextItem
        super( editor, Qt::AbstractItemDelegate.NoHint )
        # Qt seems to take care of tab wraparound
        set_current_index( model.create_index( current_index.row, current_index.column + 1 ) )
        
      when Qt::AbstractItemDelegate.EditPreviousItem
        super( editor, Qt::AbstractItemDelegate.NoHint )
        # Qt seems to take care of tab wraparound
        set_current_index( model.create_index( current_index.row, current_index.column - 1 ) )
        
      else
        super
    end
  end
  
end
