require 'rubygems'
require 'Qt4'
require 'fastercsv'
require 'clevic/model_builder.rb'

module Clevic

# The view class, implementing neat shortcuts and other pleasantness
class TableView < Qt::TableView
  attr_reader :model_class, :builder
  # whether the model is currently filtered
  # TODO better in QAbstractSortFilter?
  attr_accessor :filtered
  
  # this is emitted when this object was to display something in the status bar
  signals 'status_text(QString)'
  
  def initialize( model_class, parent, *args )
    super( parent )
    
    # the AR entity class
    @model_class = model_class
    
    # see closeEditor
    @index_override = false
    
    # set some Qt things
    self.horizontal_header.movable = false
    # TODO might be useful to allow movable vertical rows,
    # but need to change the shortcut ideas of next and previous rows
    self.vertical_header.movable = false
    self.sorting_enabled = false
    @filtered = false
    
    # turn off "Object#type deprecated" messages
    $VERBOSE = nil
  end
  
  def create_model( &block )
    raise "provide a block" unless block
    @builder = Clevic::ModelBuilder.new( self )
    @builder.instance_eval( &block )
    @builder.build
    model.connect SIGNAL( 'dataChanged ( const QModelIndex &, const QModelIndex & )' ) do |top_left, bottom_right|
      if @model_class.respond_to?( :data_changed )
        @model_class.data_changed( top_left, bottom_right, self )
      end
    end
    self
  end

  # alternative access for auto_size_column
  def auto_size_attribute( attribute, sample )
    col = model.attributes.index( attribute )
    self.set_column_width( col, column_size( col, sample ).width )
  end
  
  # set the size of the column from the sample
  def auto_size_column( col, sample )
    self.set_column_width( col, column_size( col, sample ).width )
  end

  # set the size of the column from the string value of the data
  # mostly copied from qheaderview.cpp:2301
  def column_size( col, data )
    opt = Qt::StyleOptionHeader.new
    
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
  
  # is current_index on the last row?
  def last_row?
    current_index.row == model.row_count - 1
  end
  
  # is current_index on the bottom_right cell?
  def last_cell?
    current_index.row == model.row_count - 1 && current_index.column == model.column_count - 1
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
      auto_size_column( index, field.sample )
    end
  end
  
  def moveCursor( cursor_action, modifiers )
    # TODO use this as a preload indicator
    super
  end

  # paste a CSV array to the index
  # TODO make additional rows if we need them, or at least check for enough space
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
  
  def delete_multiple_cells?
    # go ahead with delete if there's only 1 cell, or the user says OK
    delete_ok =
    if selection_model.selected_indexes.size > 1
      # confirmation message, until there are undos
      msg = Qt::MessageBox.new(
        Qt::MessageBox::Question,
        'Multiple Delete',
        'Are you sure you want to delete multiple cells?',
        Qt::MessageBox::Yes | Qt::MessageBox::No,
        self
      )
      msg.exec == Qt::MessageBox::Yes
    else
      true
    end
  end
    
  def delete_cells
    cells_deleted = false
    
    # do delete
    if delete_multiple_cells?
      selection_model.selected_indexes.each do |index|
        index.attribute_value = nil
        cells_deleted = true
      end
    end
    
    # deletes were done, so emit dataChanged
    if cells_deleted
      # emit data changed for all ranges
      selection_model.selection.each do |selection_range|
        emit dataChanged( selection_range.top_left, selection_range.bottom_right )
      end
    end
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
        if delete_multiple_cells?
          model.remove_rows( selection_model.selected_indexes.map{|index| index.row} )
        end
      
      # copy the value from the row one above  
      when event.ctrl? && event.apostrophe?
        if current_index.row > 0
          one_up_index = model.create_index( current_index.row - 1, current_index.column )
          previous_value = one_up_index.attribute_value
          if current_index.attribute_value != previous_value
            current_index.attribute_value = previous_value
            emit model.dataChanged( current_index, current_index )
          end
        end
        
      # copy the value from the previous row, one cell right
      when event.ctrl? && event.bracket_right?
        if current_index.row > 0 && current_index.column < model.column_count
          one_up_right_index = model.create_index( current_index.row - 1, current_index.column + 1 )
          current_index.attribute_value = one_up_right_index.attribute_value
          emit model.dataChanged( current_index, current_index )
        end
        
      # copy the value from the previous row, one cell left
      when event.ctrl? && event.bracket_left?
        if current_index.row > 0 && current_index.column > 0
          one_up_left_index = model.create_index( current_index.row - 1, current_index.column - 1 )
          current_index.attribute_value = one_up_left_index.attribute_value
          emit model.dataChanged( current_index, current_index )
        end
        
      # insert today's date in the current field
      when event.ctrl? && event.semicolon?
        current_index.attribute_value = Time.now
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
      
      # handle clear cells / delete rows
      when event.delete?
        # translate from ModelIndex objects to row indices
        rows = vertical_header.selection_model.selected_rows.map{|x| x.row}
        unless rows.empty?
          # header rows are selected, so delete them
          model.remove_rows( rows ) 
        else
          # otherwise various cells are selected, so delete the cells
          delete_cells
        end
        # make sure no other handlers get this event
        return true
        
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
  
  def save_current_row
    if !current_index.nil? && current_index.valid?
      save_row( current_index )
    end
  end
  
  # save the entity in the row of the given index
  # actually, model.save will check if the record
  # is really changed before writing to DB.
  def save_row( index )
    if !index.nil? && index.valid?
      saved = model.save( index )
      if !saved
        error_message = Qt::ErrorMessage.new( self )
        msg = model.collection[index.row].errors.join("\n")
        error_message.show_message( msg )
        error_message.show
      end
      saved
    end
  end
  
  # save record whenever its row is exited
  def currentChanged( current_index, previous_index )
    @index_override = false
    if current_index.row != previous_index.row
      save_row( previous_index )
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
    if !@index_override
      # move to next cell
      # Qt seems to take care of tab wraparound
      set_current_index( model_index )
    end
    @index_override = false
  end
  
  # work around situation where an ItemDelegate is open
  # when the surrouding tab is changed, but the right events
  # don't arrive.
  def hideEvent( event )
    super
    @hiding = true
  end
  
  # work around situation where an ItemDelegate is open
  # when the surrouding tab is changed, but the right events
  # don't arrive.
  def showEvent( event )
    super
    @hiding = false
  end
    
  def focusOutEvent( event )
    super
    save_current_row
  end
  
  # this is the only method that is called when an itemDelegate is open
  # and the tabs are changed.
  # Work around situation where an ItemDelegate is open
  # when the surrouding tab is changed, but the right events
  # don't arrive.
  def commitData( editor )
    super
    save_current_row if @hiding
  end
  
  # override to prevent tab pressed from editing next field
  # also takes into account that override_next_index may have been called
  def closeEditor( editor, end_edit_hint )
    puts "end_edit_hint: #{end_edit_hint.inspect}"
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

  # If self.filter is false, use the data in the indexes to filter the data set;
  # otherwise turn filtering off.
  # Sets self.filter to true if filtering worked, false otherwise.
  # indexes is a collection of Qt::ModelIndex
  def filter_by_indexes( indexes )
    unless indexes[0].field.filterable?
      emit status_text( "Can't filter on #{indexes[0].field.label}" )
      return
    end
    
    save_entity = current_index.entity
    save_index = current_index
    
    unless self.filtered
      # filter by current selection
      # TODO handle a multiple-selection
      if indexes.empty?
        self.filtered = false
      elsif indexes.size > 1
        puts "Can't do multiple selection filters yet"
        self.filtered = false
      end
      
      if indexes[0].entity.new_record?
        emit status_text( "Can't filter on a new row" )
        self.filtered = false
        return
      else
        model.reload_data( :conditions => { indexes[0].field_name => indexes[0].field_value } )
        self.filtered = true
      end
    else
      # unfilter
      model.reload_data( :conditions => {} )
      self.filtered = false
    end
    
    # find the row for the saved entity
    found_row = override_cursor( Qt::BusyCursor ) do
      model.collection.index_for_entity( save_entity )
    end
    
    # create a new index and move to it
    unless found_row.nil?
      self.current_index = model.create_index( found_row, save_index.column )
    end
  end
  
  # search_criteria must respond to:
  # * search_text
  # * whole_words?
  # * direction ( :forward, :backward )
  # * from_start?
  #
  # TODO formalise this
  def search( search_criteria )
    indexes = model.search( current_index, search_criteria )
    if indexes.size > 0
      emit status_text( "Found #{search_criteria.search_text} at row #{indexes[0].row}" )
      selection_model.clear
      self.current_index = indexes[0]
    else
      emit status_text( "No match found for #{search_criteria.search_text}" )
    end
  end

  def itemDelegateForColumn( column )
    puts "itemDelegateForColumn #{column}"
    super
  end
end

end
