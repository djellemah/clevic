require 'Qt4'
require 'clevic/entry_builder.rb'
require 'fastercsv'

# The view class, implementing neat shortcuts and other pleasantness
class EntryTableView < Qt::TableView
  attr_reader :model_class, :builder
  # whether the model is currently filtered
  # TODO better in QAbstractSortFilter?
  attr_accessor :filtered
  
  def initialize( model_class, parent, *args )
    super( parent )
    
    # the AR entity class
    @model_class = model_class
    
    # see closeEditor
    @index_override = false
    
    # set some Qt things
    self.horizontal_header.movable = true
    # TODO might be useful to allow movable vertical rows,
    # but need to change the shortcut ideas of next and previous rows
    self.vertical_header.movable = false
    self.sorting_enabled = true
    @filtered = false
    
    # turn off "Object#type deprecated" messages
    $VERBOSE = nil
  end
  
  def create_model( &block )
    @builder = EntryBuilder.new( self )
    yield( @builder )
    @builder.build
    model.connect( SIGNAL( 'dataChanged ( const QModelIndex &, const QModelIndex & )' ) ) do |top_left, bottom_right|
      if @model_class.respond_to?( :data_changed )
        @model_class.data_changed( top_left, bottom_right, self )
      end
    end
    self
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
    #~ initStyleOption( opt )
    
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
    # not necessary after setting vertical_header.default_section_size in setModel
    section_size = vertical_header.minimum_section_size
    rows.each do |row|
      vertical_header.resize_section( row, section_size )
    end
  end
  
  # make sure row size is correct
  # show error messages for data
  def setModel( model )
    vertical_header.default_section_size = vertical_header.minimum_section_size
    super
    
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
    resize_columns
  end
  
  # resize all fields based on heuristics rather
  # than iterating through the entire data model
  def resize_columns
    @builder.fields.each_with_index do |field, index|
      auto_size_column( index, field.sample ) unless field.sample.nil?
    end
  end
  
  def paste_to_index( top_left_index, csv_arr )
    csv_arr.each_with_index do |row,row_index|
      row.each_with_index do |field, field_index|
        cell_index = model.create_index( top_left_index.row + row_index, top_left_index.column + field_index )
        model.setData( cell_index, field.to_variant, Qt::PasteRole )
      end
      # save records to db
      model.save( model.create_index( top_left_index.row + row_index, 0 ) )
    end
    
    # make the gui refresh
    bottom_right_index = model.create_index( top_left_index.row + csv_arr.size - 1, top_left_index.column + csv_arr[0].size - 1 )
    emit model.dataChanged( top_left_index, bottom_right_index )
    emit model.headerDataChanged( Qt::Vertical, top_left_index.row, top_left_index.row + csv_arr.size )
  end
  
  def keyPressEvent( event )
    # for some reason, trying to call another method inside
    # the begin .. rescue block throws a superclass method not
    # found error. Weird.
    begin
      # call to model class for shortcuts
      if model.model_class.respond_to?( :key_press_event )
        begin
          model_result = model.model_class.key_press_event( event, current_index, self )
          return model_result if model_result != nil
        rescue Exception => e
          puts e.backtrace
          error_message = Qt::ErrorMessage.new( self )
          error_message.show_message( "Error in shortcut handler for #{model.model_class.name}: #{e.message}" )
          error_message.show
        end
      end
      
      # now do all the usual shortcuts
      case
      # on the last row, and down is pressed
      # add a new row
      when event.down? && last_row?
        model.add_new_item
        
      # on the right-bottom cell, and tab is pressed
      # then add a new row
      when event.tab? && last_cell?
        model.add_new_item
        
      # delete the current row
      when event.ctrl? && event.delete?
        model.remove_rows( [ current_index.row ] ) 
      
      # copy the value from the row one above  
      when event.ctrl? && event.apostrophe?
        if current_index.row > 0
          key = current_index.attribute
          previous_item = model.collection[current_index.row - 1]
          current_item = model.collection[current_index.row]
          
          previous_value = previous_item.send( key )
          current_value = current_item.send( key )
          if current_value != previous_value
            current_item.send( "#{key}=", previous_value )
            emit model.dataChanged( current_index, current_index )
          end
        end
        
      # copy the value from the previous row, one cell right
      when event.ctrl? && event.bracket_right?
        if current_index.row > 0 && current_index.column < model.column_count
          key = current_index.attribute
          previous_item = model.collection[current_index.row - 1]
          current_item = model.collection[current_index.row]
          current_item.send( "#{key}=", previous_item.send( model.attributes[ current_index.column + 1 ] ) )
          emit model.dataChanged( current_index, current_index )
        end
        
      # copy the value from the previous row, one cell left
      when event.ctrl? && event.bracket_left?
        if current_index.row > 0 && current_index.column > 0
          key = current_index.attribute
          previous_item = model.collection[current_index.row - 1]
          current_item = model.collection[current_index.row]
          current_item.send( "#{key}=", previous_item.send( model.attributes[ current_index.column - 1 ] ) )
          emit model.dataChanged( current_index, current_index )
        end
        
      # insert today's date in the current field
      when event.ctrl? && event.semicolon?
        key = current_index.attribute
        current_item = model.collection[current_index.row]
        current_item.send( "#{key}=", Time.now )
        emit model.dataChanged( current_index, current_index )
        
      # dump current record to stdout
      when event.ctrl? && event.d?
        puts model.collection[current_index.row].inspect
        
      # add new record and go to it
      when event.ctrl? && ( event.n? || event.return? )
        model.add_new_item
        new_row_index = model.index( model.collection.size - 1, 0 )
        currentChanged( new_row_index, current_index )
        selection_model.clear
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
        delegate.full_edit
        
      # copy currently selected data in csv format
      when event.ctrl? && event.c?
        text = String.new
        selection_model.selection.each do |selection_range|
          (selection_range.top..selection_range.bottom).each do |row|
            row_ary = Array.new
            selection_model.selected_indexes.each do |index|
              row_ary << index.gui_value if index.row == row
            end
            text << row_ary.to_csv
          end
        end
        Qt::Application::clipboard.text = text
        return true
        
      when event.ctrl? && event.v?
        # remove trailing "\n" if there is one
        text = Qt::Application::clipboard.text.chomp
        arr = FasterCSV.parse( text )
        
        return true if selection_model.selection.size != 1
        
        selection_range = selection_model.selection[0]
        selected_index = selection_model.selected_indexes[0]
        
        if selection_range.single_cell?
          # only one cell selected, so paste like a spreadsheet
          if text.empty?
            # just clear the current selection
            model.setData( selected_index, nil.to_variant )
          else
            paste_to_index( selected_index, arr )
          end
        else
          return true if selection_range.height != arr.size
          return true if selection_range.width != arr[0].size
          
          # size is the same, so do the paste
          paste_to_index( selected_index, arr )
        end
        return true
        
      else
        #~ puts event.inspect
      end
      super
    rescue Exception => e
      puts e.backtrace.join( "\n" )
      puts e.message
      error_message = Qt::ErrorMessage.new( self )
      error_message.show_message( "Error in #{current_index.attribute.to_s}: \"#{e.message}\"" )
      error_message.show
    end
  end
  
  # save record whenever its row is exited
  def currentChanged( current_index, previous_index )
    @index_override = false
    if current_index.row != previous_index.row
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
  
  # this is to allow entity model UI handlers to tell the view
  # where to move the current editing index to. If it's left blank
  # default is based on the editing hint.
  # see closeEditor
  def override_next_index( model_index )
    set_current_index( model_index )
    @index_override = true
  end
  
  # call set_current_index with model_index unless override is true.
  def set_current_unless_override( model_index )
    if ( !@index_override )
      # move to next cell
      # Qt seems to take care of tab wraparound
      set_current_index( model_index )
    end
    @index_override = false
  end
    
  # override to prevent tab pressed from editing next field
  # also takes into account that override_next_index may have been called
  def closeEditor( editor, end_edit_hint )
    case end_edit_hint
      when Qt::AbstractItemDelegate.EditNextItem
        super( editor, Qt::AbstractItemDelegate.NoHint )
        set_current_unless_override( model.create_index( current_index.row, current_index.column + 1 ) )
        
      when Qt::AbstractItemDelegate.EditPreviousItem
        super( editor, Qt::AbstractItemDelegate.NoHint )
        set_current_unless_override( model.create_index( current_index.row, current_index.column - 1 ) )
        
      else
        super
    end
  end

  def filter_by_indexes( indexes )
    save_entity = current_index.entity
    save_index = current_index
    
    if !self.filtered
      # filter by current selection
      # TODO handle a multiple-selection
      if indexes.empty?
        self.filtered = false
      elsif indexes.size > 1
        puts "Can't do multiple selection filters yet"
        self.filtered = false
      end
      
      model.reload_data( :conditions => { indexes[0].field_name => indexes[0].field_value } )
      self.filtered = true
    else
      # unfilter
      model.reload_data( :conditions => {} )
      self.filtered = false
    end
    
    # find the row for the saved entity
    found_row = model.collection.index_for_entity( save_entity )
    
    # create a new index and move to it
    current_index = model.create_index( found_row, save_index.column )
  end
end
