require 'rubygems'
require 'Qt4'
require 'fastercsv'
require 'qtext/action_builder.rb'

require 'clevic/model_builder.rb'
require 'clevic/filter_command.rb'

module Clevic

# The view class
class TableView < Qt::TableView
  include ActionBuilder
  
  # the current filter command
  # TODO better in QAbstractSortFilter?
  attr_accessor :filtered
  def filtered?; !@filtered.nil?; end
  
  # status_text is emitted when this object was to display something in the status bar
  # error_test is emitted when an error of some kind must be displayed to the user.
  # filter_status is emitted when the filtering changes. Param is true for filtered, false for not filtered.
  signals 'status_text(QString)', 'filter_status(bool)'
  
  # arg is:
  # - an instance of Clevic::View
  # - an instance of TableModel
  def initialize( arg, parent = nil, &block )
    # need the empty block here, otherwise Qt bindings grab &block
    super( parent ) {}
    
    # the model/entity_class/builder
    case 
      when arg.kind_of?( TableModel )
        self.model = arg
        init_actions( arg.entity_view )
      
      else
        # arg is a subclass of Clevic::View
        model_builder = arg.define_ui
        model_builder.exec_ui_block( &block )
        
        # make sure the TableView has a fully-populated TableModel
        # self.model is necessary to invoke the Qt layer
        self.model = model_builder.build( self )
        self.object_name = arg.widget_name
        
        # connect data_changed signals for the entity_class to respond
        connect_view_signals( arg )
        
        init_actions( arg )
    end
      
    # see closeEditor
    @index_override = false
    
    # set some Qt things
    self.horizontal_header.movable = false
    # TODO might be useful to allow movable vertical rows,
    # but need to change the shortcut ideas of next and previous rows
    self.vertical_header.movable = false
    self.sorting_enabled = false
    
    self.context_menu_policy = Qt::ActionsContextMenu
  end
  
  def title
    @title ||= model.entity_view.title
  end
  
  def connect_view_signals( entity_view )
    model.connect SIGNAL( 'dataChanged ( const QModelIndex &, const QModelIndex & )' ) do |top_left, bottom_right|
      entity_view.notify_data_changed( self, top_left, bottom_right )
    end
  end
  
  # find the row index for the given field id (symbol)
  def field_column( field )
    model.fields.each_with_index {|x,i| return i if x.id == field }
  end
    
  # return menu actions for the model, or an empty array if there aren't any
  def model_actions
    @model_actions ||= []
  end
  
  # hook for the sanity_check_xxx methods
  # called for the actions set up by ActionBuilder
  # it just wraps the action block/method in a catch
  # block for :insane. Will also catch exceptions thrown in actions to make
  # core application more robust to model & view errors.
  def action_triggered( &block )
    begin
      catch :insane do
        yield
      end
    rescue Exception => e
      puts e.message
      puts e.backtrace
    end
  end
  
  def init_actions( entity_view )
    # add model actions, if they're defined
    list( :model ) do |ab|
      entity_view.define_actions( self, ab )
      separator
    end
    
    # list of actions in the edit menu
    list( :edit ) do
      #~ new_action :action_cut, 'Cu&t', :shortcut => Qt::KeySequence::Cut
      action :action_copy, '&Copy', :shortcut => Qt::KeySequence::Copy, :method => :copy_current_selection
      action :action_paste, '&Paste', :shortcut => Qt::KeySequence::Paste, :method => :paste
      separator
      action :action_ditto, '&Ditto', :shortcut => 'Ctrl+\'', :method => :ditto, :tool_tip => 'Copy same field from previous record'
      action :action_ditto_right, 'Ditto R&ight', :shortcut => 'Ctrl+]', :method => :ditto_right, :tool_tip => 'Copy field one to right from previous record'
      action :action_ditto_left, '&Ditto L&eft', :shortcut => 'Ctrl+[', :method => :ditto_left, :tool_tip => 'Copy field one to left from previous record'
      action :action_insert_date, 'Insert Date', :shortcut => 'Ctrl+;', :method => :insert_current_date
      action :action_open_editor, '&Open Editor', :shortcut => 'F4', :method => :open_editor
      separator
      action :action_row, 'New Ro&w', :shortcut => 'Ctrl+N', :method => :new_row
      action :action_refresh, '&Refresh', :shortcut => 'Ctrl+R', :method => :refresh
      action :action_delete_rows, 'Delete Rows', :shortcut => 'Ctrl+Delete', :method => :delete_rows
      
      if $options[:debug]
        action :action_dump, 'D&ump', :shortcut => 'Ctrl+Shift+D' do
          puts model.collection[current_index.row].inspect
        end
      end
    end
    
    separator
    
    # list of actions called search
    list( :search ) do
      action :action_find, '&Find', :shortcut => Qt::KeySequence::Find, :method => :find
      action :action_find_next, 'Find &Next', :shortcut => Qt::KeySequence::FindNext, :method => :find_next
      action :action_filter, 'Fil&ter', :checkable => true, :shortcut => 'Ctrl+L', :method => :filter_by_current
      action :action_highlight, '&Highlight', :visible => false, :shortcut => 'Ctrl+H'
    end
  end
  
  def copy_current_selection
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
  end
  
  def paste
    sanity_check_read_only
    
    # remove trailing "\n" if there is one
    text = Qt::Application::clipboard.text.chomp
    arr = FasterCSV.parse( text )
    
    return true if selection_model.selection.size != 1
    
    selection_range = selection_model.selection.first
    selected_index = selection_model.selected_indexes.first
    
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
      return true if selection_range.width != arr.first.size
      
      # size is the same, so do the paste
      paste_to_index( selected_index, arr )
    end
  end
  
  def sanity_check_ditto
    if current_index.row == 0
      emit status_text( 'No previous record to copy.' )
      throw :insane
    end
  end
  
  def sanity_check_read_only
    if current_index.field.read_only?
      emit status_text( 'Can\'t copy into read-only field.' )
    elsif current_index.entity.readonly?
      emit status_text( 'Can\'t copy into read-only record.' )
    else
      sanity_check_read_only_table
      return
    end
    throw :insane
  end
  
  def sanity_check_read_only_table
    if model.read_only?
      emit status_text( 'Can\'t modify a read-only table.' )
      throw :insane
    end
  end
  
  def ditto
    sanity_check_ditto
    sanity_check_read_only
    one_up_index = current_index.choppy { |i| i.row -= 1 }
    previous_value = one_up_index.attribute_value
    if current_index.attribute_value != previous_value
      current_index.attribute_value = previous_value
      emit model.dataChanged( current_index, current_index )
    end
  end
  
  # from and to are ModelIndex instances. Throws :insane if
  # their fields don't have the same attribute_type.
  def sanity_check_types( from, to )
    unless from.field.attribute_type == to.field.attribute_type
      emit status_text( 'Incompatible data' )
      throw :insane
    end
  end
  
  def ditto_right
    sanity_check_ditto
    sanity_check_read_only
    if current_index.column >= model.column_count - 1
      emit status_text( 'No column to the right' )
    else
      one_up_right = current_index.choppy {|i| i.row -= 1; i.column += 1 }
      sanity_check_types( one_up_right, current_index )
      current_index.attribute_value = one_up_right.attribute_value
      emit model.dataChanged( current_index, current_index )
    end
  end
  
  def ditto_left
    sanity_check_ditto
    sanity_check_read_only
    unless current_index.column > 0
      emit status_text( 'No column to the left' )
    else
      one_up_left = current_index.choppy { |i| i.row -= 1; i.column -= 1 }
      sanity_check_types( one_up_left, current_index )
      current_index.attribute_value = one_up_left.attribute_value
      emit model.dataChanged( current_index, current_index )
    end
  end
  
  def insert_current_date
    sanity_check_read_only
    current_index.attribute_value = Time.now
    emit model.dataChanged( current_index, current_index )
  end
  
  def open_editor
    edit( current_index )
    delegate = item_delegate( current_index )
    delegate.full_edit
  end
  
  # Add a new row and move to it, provided we're not in a read-only view.
  def new_row
    sanity_check_read_only_table
    model.add_new_item
    new_row_index = model.index( model.row_count - 1, 0 )
    currentChanged( new_row_index, current_index )
    selection_model.clear
    self.current_index = new_row_index
  end
  
  # Delete the current selection. If it's a set of rows, just delete
  # them. If it's a rectangular selection, set the cells to nil.
  # TODO make sure all affected rows are saved.
  def delete_selection
    sanity_check_read_only

    # translate from ModelIndex objects to row indices
    rows = vertical_header.selection_model.selected_rows.map{|x| x.row}
    unless rows.empty?
      # header rows are selected, so delete them
      model.remove_rows( rows ) 
    else
      # otherwise various cells are selected, so delete the cells
      delete_cells
    end
  end
  
  # display a search dialog, and find the entered text
  def find
    @search_dialog ||= SearchDialog.new
    result = @search_dialog.exec( current_index.gui_value )
    
    override_cursor( Qt::BusyCursor ) do
      case result
        when Qt::Dialog::Accepted
          search_for = @search_dialog.search_text
          search( @search_dialog )
        when Qt::Dialog::Rejected
          puts "Don't search"
        else
          puts "unknown dialog code #{result}"
      end
    end
  end
  
  def find_next
    if @search_dialog.nil?
      emit status_text( 'No previous find' )
    else
      override_cursor( Qt::BusyCursor ) do
        save_from_start = @search_dialog.from_start?
        @search_dialog.from_start = false
        search( @search_dialog )
        @search_dialog.from_start = save_from_start
      end
    end
  end
  
  # force a complete reload of the current tab's data
  def refresh
    override_cursor( Qt::BusyCursor ) do
      restore_entity do
        model.reload_data
      end
    end
  end
  
  # return an array of the current selection, or the
  # current index in an array if the selection is empty
  def selection_or_current
    indexes_or_current( selection_model.selected_indexes )
  end
  
  def selected_rows_or_current
    indexes_or_current( selection_model.selected_rows )
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
    fnt.bold = true
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
    # must do this otherwise model gets garbage collected
    @model = model
    
    # make sure we get nice spacing
    vertical_header.default_section_size = vertical_header.minimum_section_size
    super
    
    # set delegates
    #~ self.item_delegate = Clevic::ItemDelegate.new( self, field )
    model.fields.each_with_index do |field, index|
      set_item_delegate_for_column( index, field.delegate )
    end
    
    # data errors
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
    model.fields.each_with_index do |field, index|
      auto_size_column( index, field.sample )
    end
  end
  
  def moveCursor( cursor_action, modifiers )
    # TODO use this as a preload indicator
    super
  end

  # copied from actionpack
  def pluralize(count, singular, plural = nil)
    "#{count || 0} " + ((count == 1 || count == '1') ? singular : (plural || singular.pluralize))
  end

  # Paste a CSV array to the index, replacing whatever is at that index
  # and whatever is at other indices matching the size of the pasted
  # csv array. Create new rows if there aren't enough.
  def paste_to_index( top_left_index, csv_arr )
    csv_arr.each_with_index do |row,row_index|
      # append row if we need one
      model.add_new_item if top_left_index.row + row_index >= model.row_count
      
      row.each_with_index do |field, field_index|
        unless top_left_index.column + field_index >= model.column_count
          # do paste
          cell_index = top_left_index.choppy {|i| i.row += row_index; i.column += field_index }
          model.setData( cell_index, field.to_variant, Qt::PasteRole )
        else
          emit status_text( "#{pluralize( top_left_index.column + field_index, 'column' )} for pasting data is too large. Truncating." )
        end
      end
      # save records to db
      model.save( top_left_index.choppy {|i| i.row += row_index; i.column = 0 } )
    end
    
    # make the gui refresh
    bottom_right_index = top_left_index.choppy {|i| i.row += csv_arr.size - 1; i.column += csv_arr.first.size - 1 }
    emit model.dataChanged( top_left_index, bottom_right_index )
    emit model.headerDataChanged( Qt::Vertical, top_left_index.row, top_left_index.row + csv_arr.size )
  end
  
  # ask the question in a dialog. If the user says yes, execute the block
  def delete_multiple_cells?( question = 'Are you sure you want to delete multiple cells?', &block )
    sanity_check_read_only
    
    # go ahead with delete if there's only 1 cell, or the user says OK
    delete_ok =
    if selection_model.selected_indexes.size > 1
      # confirmation message, until there are undos
      msg = Qt::MessageBox.new(
        Qt::MessageBox::Question,
        'Multiple Delete',
        question,
        Qt::MessageBox::Yes | Qt::MessageBox::No,
        self
      )
      msg.exec == Qt::MessageBox::Yes
    else
      true
    end
    
    yield if delete_ok
  end
  
  # Ask if multiple cell delete is OK, then replace contents
  # of selected cells with nil.
  def delete_cells
    delete_multiple_cells? do
      cells_deleted = false
      
      # do delete
      selection_model.selected_indexes.each do |index|
        index.attribute_value = nil
        cells_deleted = true
      end
      
      # deletes were done, so emit dataChanged
      if cells_deleted
        # save affected rows
        selection_model.selected_rows.each { |index| index.entity.save }
        
        # emit data changed for all ranges
        selection_model.selection.each do |selection_range|
          emit dataChanged( selection_range.top_left, selection_range.bottom_right )
        end
      end
    end
  end
  
  def delete_rows
    delete_multiple_cells?( 'Are you sure you want to delete multiple rows?' ) do
      model.remove_rows( selection_model.selected_indexes.map{|index| index.row} )
    end
  end
  
  # handle certain key combinations that aren't shortcuts
  def keyPressEvent( event )
    begin
      # call to entity class for shortcuts
      begin
        view_result = model.entity_view.notify_key_press( self, event, current_index )
        return view_result unless view_result.nil?
      rescue Exception => e
        puts e.backtrace
        error_message = Qt::ErrorMessage.new( self )
        error_message.show_message( "Error in shortcut handler for #{model.entity_view.name}: #{e.message}" )
        error_message.show
      end
      
      # thrown by the sanity_check_xxx methods
      catch :insane do
        case
        # on the last row, and down is pressed
        # add a new row
        when event.down? && last_row?
          new_row
          
        # on the right-bottom cell, and tab is pressed
        # then add a new row
        when event.tab? && last_cell?
          new_row
          
        # add new record and go to it
        # TODO this is actually a shortcut
        when event.ctrl? && event.return?
          new_row
        
        when event.delete?
          if selection_model.selected_indexes.size > 1
            delete_selection
            return true
          end
        
        else
          #~ puts event.inspect
        end
      end
      super
    rescue Exception => e
      puts e.backtrace
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
        msg = model.collection[index.row].errors.to_a.join("\n")
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
    #~ save_current_row
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
    puts "end_edit_hint: #{end_edit_hint.inspect}" if $options[:debug]
    case end_edit_hint
      when Qt::AbstractItemDelegate.EditNextItem
        super( editor, Qt::AbstractItemDelegate.NoHint )
        set_current_unless_override( current_index.choppy { |i| i.column += 1 } )
        
      when Qt::AbstractItemDelegate.EditPreviousItem
        super( editor, Qt::AbstractItemDelegate.NoHint )
        set_current_unless_override( current_index.choppy { |i| i.column -= 1 } )
        
      else
        super
    end
  end
  
  # toggle the filter, based on current selection.
  def filter_by_current( bool_filter )
    filter_by_indexes( selection_or_current )
  end
  
  def filter_by_options( args )
    filtered.undo if filtered?
    self.filtered = FilterCommand.new( self, [], args )
    emit filter_status( filtered.doit )
  end
  
  # Save the current entity, do something, then restore
  # the cursor position to the entity if possible.
  # Return the result of the block.
  def restore_entity( &block )
    save_entity = current_index.entity
    unless save_entity.nil?
      save_entity.save if save_entity.changed?
      save_index = current_index
    end
    
    retval = yield
    
    # find the entity if possible
    select_entity( save_entity, save_index.column ) unless save_entity.nil?
    
    retval
  end

  # Filter by the value in the current index.
  # indexes is a collection of Qt::ModelIndex
  def filter_by_indexes( indexes )
    case
      when filtered?
        # unfilter
        restore_entity do
          filtered.undo
          self.filtered = nil
          # update status bar
          emit status_text( nil )
          emit filter_status( false )
        end
        
      when indexes.empty?
        emit status_text( "No field selected for filter" )
        
      when !indexes.first.field.filterable?
        emit status_text( "Can't filter on #{indexes.first.field.label}" )
      
      when indexes.size > 1
        emit status_text( "Can't do multiple selection filters yet" )
      
      when indexes.first.entity.new_record?
        emit status_text( "Can't filter on a new row" )
        
      else
        self.filtered = FilterCommand.new( self, indexes, :conditions => { indexes.first.field_name => indexes.first.field_value } )
        # try to end up on the same entity, even after the filter
        restore_entity do
          emit filter_status( filtered.doit )
        end
        # update status bar
        emit status_text( filtered.status_message )
      end
      filtered?
  end
  
  # Move to the row for the given entity and the given column.
  # If column is a symbol,
  # field_column will be called to find the integer index.
  def select_entity( entity, column = nil )
    # sanity check that the entity can actually be found
    Kernel.raise "entity is nil" if entity.nil?
    unless entity.class == model.entity_class
      Kernel.raise "entity #{entity.class.name} does not match class #{model.entity_class.name}"
    end
    
    # find the row for the saved entity
    found_row = override_cursor( Qt::BusyCursor ) do
      model.collection.index_for_entity( entity )
    end
    
    # create a new index and move to it
    unless found_row.nil?
      column = field_column( column ) if column.is_a? Symbol
      selection_model.clear
      self.current_index = model.create_index( found_row, column || 0 )
    end
  end
  
  # search_criteria must respond to:
  # * search_text
  # * whole_words?
  # * direction ( :forward, :backward )
  # * from_start?
  #
  # TODO formalise this?
  def search( search_criteria )
    indexes = model.search( current_index, search_criteria )
    if indexes.size > 0
      emit status_text( "Found #{search_criteria.search_text} at row #{indexes.first.row}" )
      selection_model.clear
      self.current_index = indexes.first
    else
      emit status_text( "No match found for #{search_criteria.search_text}" )
    end
  end

  def itemDelegateForColumn( column )
    puts "itemDelegateForColumn #{column}"
    super
  end

  # find the TableView instance for the given entity_view
  # or entity_model. Return nil if no match found.
  # TODO doesn't really belong here because TableView will not always
  # be in a TabWidget context.
  def find_table_view( entity_model_or_view )
    parent.children.find do |x|
      if x.is_a? TableView
        x.model.entity_view.class == entity_model_or_view || x.model.entity_class == entity_model_or_view
      end
    end
  end
  
  # execute the block with the TableView instance
  # currently handling the entity_model_or_view.
  # Don't execute the block if nothing is found.
  # TODO doesn't really belong here because TableView will not always
  # be in a TabWidget context.
  def with_table_view( entity_model_or_view, &block )
    tv = find_table_view( entity_model_or_view )
    yield( tv ) unless tv.nil?
  end
  
  # make this window visible if it's in a TabWidget
  # TODO doesn't really belong here because TableView will not always
  # be in a TabWidget context.
  def raise
    # the tab's parent is a StackedWiget, and its parent is TabWidget
    tab_widget = parent.parent
    tab_widget.current_widget = self if tab_widget.class == Qt::TabWidget
  end
  
protected

  # return either the set of indexes with all invalid indexes
  # remove, or the current selection.
  def indexes_or_current( indexes )
    retval =
    if indexes.empty?
      [ current_index ]
    else
      indexes
    end
    
    # strip out bad indexes, so other things don't have to check
    # can't use select because copying indexes causes an abort
    #~ retval.select{|x| x != nil && x.valid?}
    retval.reject!{|x| x.nil? || !x.valid?}
    # retval needed here because reject! returns nil if nothing was rejected
    retval
  end
  
end

end
