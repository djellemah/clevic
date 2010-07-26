require 'rubygems'
require 'Qt4'
require 'fastercsv'
require 'qtext/action_builder.rb'

require 'clevic/model_builder.rb'
require 'clevic/filter_command.rb'

module Clevic

# The view class
class TableView < Qt::TableView
  include Clevic::TableView
  include ActionBuilder
  
  # status_text is emitted when this object was to display something in the status bar
  # filter_status is emitted when the filtering changes. Param is true for filtered, false for not filtered.
  signals 'status_text(QString)', 'filter_status(bool)'
  
  # arg is:
  # - an instance of Clevic::View
  # - an instance of TableModel
  def initialize( arg, parent = nil, &block )
    # need the empty block here, otherwise Qt bindings grab &block
    super( parent ) {}
    
    framework_init( arg, &block )
    
    # see closeEditor
    @next_index = nil
    
    # set some Qt things
    self.horizontal_header.movable = false
    # TODO might be useful to allow movable vertical rows,
    # but need to change the shortcut ideas of next and previous rows
    self.vertical_header.movable = false
    self.sorting_enabled = false
    
    self.context_menu_policy = Qt::ActionsContextMenu
  end
  
  def connect_view_signals( entity_view )
    model.connect SIGNAL( 'dataChanged ( const QModelIndex &, const QModelIndex & )' ) do |top_left, bottom_right|
      begin
        entity_view.notify_data_changed( self, top_left, bottom_right )
      rescue Exception => e
        puts
        puts "#{model.entity_view.class.name}: #{e.message}"
        puts e.backtrace
      end
    end
  end
  
  # pull in Qt-specific keys
  def old_init_actions( entity_view )
    # add model actions, if they're defined
    list( :model ) do |ab|
      entity_view.define_actions( self, ab )
      separator
    end
    
    # list of actions in the edit menu
    list( :edit ) do
      #~ new_action :action_cut, 'Cu&t', :shortcut => Qt::KeySequence::Cut
      action :action_save, '&Save', :shortcut => Qt::KeySequence::Save, :method => :save_current_row
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
    Qt::Application::clipboard.text = current_selection_csv
  end
  
  def selected_rows
    rows = []
    selection_model.selection.each do |selection_range|
      (selection_range.top..selection_range.bottom).each do |row|
        rows << row
      end
    end
    rows
  end
  
  # TODO refactor with Clevic::TableView
  def paste
    sanity_check_read_only
    
    # remove trailing "\n" if there is one
    text = Qt::Application::clipboard.text.chomp
    arr = FasterCSV.parse( text )
    
    selection_model.selected_indexes.
    return true if selection_model.selection.size != 1
    
    selection_range = selection_model.selection.first
    selected_index = selection_model.selected_indexes.first
    
    if selection_model.selection.size == 1 && selection_range.single_cell?
      # only one cell selected, so paste like a spreadsheet
      if text.empty?
        # just clear the current selection
        model.setData( selected_index, nil.to_variant )
      else
        paste_to_index( selected_index, arr )
      end
    else
      if arr.size == 1 && arr.first.size == 1
        # only one value to paste, and multiple selection, so
        # set all selected indexes to the value
        value = arr.first.first
        selection_model.selected_indexes.each do |index|
          model.setData( index, value.to_variant, Qt::PasteRole )
          # save records to db
          model.save( index )
        end
        
        # notify of changed data
        model.data_changed do |change|
          sorted = selection_model.selected_indexes.sort
          change.top_left = sorted.first
          change.bottom_right = sorted.last
        end
      else
        return true if selection_range.height != arr.size
        return true if selection_range.width != arr.first.size
        
        # size is the same, so do the paste
        paste_to_index( selected_index, arr )
      end
    end
  end
  
  def status_text( msg )
    emit status_text( msg )
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
      model.data_changed( current_index )
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
      model.data_changed( current_index )
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
      model.data_changed( current_index )
    end
  end
  
  def insert_current_date
    sanity_check_read_only
    current_index.attribute_value = Time.now
    model.data_changed( current_index )
  end
  
  def open_editor
    edit( current_index )
    delegate = item_delegate( current_index )
    delegate.full_edit
  end
  
  def itemDelegate( model_index )
    @pre_delegate_index = model_index
    super
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
    indexes_or_current( selection_model.row_indexes )
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
  
  # TODO is this even used?
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
    model.data_changed do |change|
      change.top_left = top_left_index
      change.bottom_right = top_left_index.choppy do |i|
        i.row += csv_arr.size - 1
        i.column += csv_arr.first.size - 1
      end
    end
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
      
      # deletes were done, so call data_changed
      if cells_deleted
        # save affected rows
        selection_model.row_indexes.each do |index|
          index.entity.save
        end
        
        # emit data changed for all ranges
        selection_model.selection.each do |selection_range|
          model.data_changed( selection_range )
        end
      end
    end
  end
  
  def delete_rows
    delete_multiple_cells?( 'Are you sure you want to delete multiple rows?' ) do
      model.remove_rows( selection_model.selected_indexes.map{|index| index.row} )
    end
  end
  
  def keyPressEvent( event )
    handle_key_press( event )
  end
  
  def set_model_data( table_index, value )
    model.setData( table_index, value.to_variant, Qt::PasteRole )
  end

  # save the entity in the row of the given index
  # actually, model.save will check if the record
  # is really changed before writing to DB.
  def show_error( msg )
    error_message = Qt::ErrorMessage.new( self )
    error_message.show_message( msg )
    error_message.show
  end
  
  # save record whenever its row is exited
  def currentChanged( current_index, previous_index )
    if previous_index.valid? && current_index.row != previous_index.row
      self.next_index = nil
      save_row( previous_index )
    end
    super
  end
  
  # This is to allow entity model UI handlers to tell the view
  # whence to move the cursor when the current editor closes
  # (see closeEditor).
  # TODO not used?
  def override_next_index( model_index )
    self.next_index = model_index
  end
  
  # Call set_current_index with next_index ( from override_next_index )
  # or model_index, in that order. Set next_index to nil afterwards.
  def set_current_unless_override( model_index )
    set_current_index( @next_index || model_index )
    self.next_index = nil
  end
  
  # work around situation where an ItemDelegate is open
  # when the surrouding tab is changed, but the right events
  # don't arrive.
  def hideEvent( event )
    # can't call super here, for some reason. Qt binding says method not found.
    # super
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
  
  # bool QAbstractItemView::edit ( const QModelIndex & index, EditTrigger trigger, QEvent * event )
  def edit( model_index, trigger = nil, event = nil )
    self.before_edit_index = model_index
    #~ puts "edit model_index: #{model_index.inspect}"
    #~ puts "trigger: #{trigger.inspect}"
    #~ puts "event: #{event.inspect}"
    if trigger.nil? && event.nil?
      super( model_index )
    else
      super( model_index, trigger, event )
    end
    
    rescue Exception => e
      raise RuntimeError, "#{model.entity_view.class.name}.#{model_index.field.id}: #{e.message}", caller(0)
  end
  
  attr_accessor :before_edit_index
  attr_reader :next_index
  def next_index=( other_index )
    if $options[:debug]
      puts "debug trace only - not a rescue"
      puts caller
      puts "next index to #{other_index.inspect}"
      puts
    end
    @next_index = other_index
  end
  
  # set and move to index. Leave index value in next_index
  # so that it's not overridden later.
  # TODO All this next_index stuff is becoming a horrible hack.
  def next_index!( model_index )
    self.current_index = self.next_index = model_index
  end
  
  # override to prevent tab pressed from editing next field
  # also takes into account that override_next_index may have been called
  def closeEditor( editor, end_edit_hint )
    if $options[:debug]
      puts "end_edit_hint: #{Qt::AbstractItemDelegate.constants.find {|x| Qt::AbstractItemDelegate.const_get(x) == end_edit_hint } }"
      puts "next_index: #{next_index.inspect}"
    end
    
    subsequent_index =
    case end_edit_hint
      when Qt::AbstractItemDelegate.EditNextItem
        super( editor, Qt::AbstractItemDelegate.NoHint )
        before_edit_index.choppy { |i| i.column += 1 }
        
      when Qt::AbstractItemDelegate.EditPreviousItem
        super( editor, Qt::AbstractItemDelegate.NoHint )
        before_edit_index.choppy { |i| i.column -= 1 }
      
      else
        super
        nil
    end
    
    unless subsequent_index.nil?
      puts "subsequent_index: #{subsequent_index.inspect}" if $options[:debug]
      # TODO all this really does is reset next_index
      set_current_unless_override( next_index || subsequent_index || before_edit_index )
      self.before_edit_index = nil
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
  def raise_widget
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
