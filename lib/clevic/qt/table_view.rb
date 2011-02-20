require 'fastercsv'
require 'qtext/action_builder.rb'
require 'clevic/model_builder.rb'
require 'clevic/filter_command.rb'

module Clevic

# The view class
# TODO not sure if we still need override_next_index and friends
class TableView < Qt::TableView
  include ActionBuilder
  
  # status_text is emitted when this object was to display something in the status bar
  # filter_status is emitted when the filtering changes. Param is true for filtered, false for not filtered.
  signals 'status_text_signal(QString)', 'filter_status_signal(bool)'
  
  def emit_filter_status( bool )
    emit filter_status_signal( bool )
  end
  
  def emit_status_text( string )
    emit status_text_signal( string )
  end
  
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
    self.vertical_header.default_alignment = Qt::AlignTop | Qt::AlignRight
    self.sorting_enabled = false
    
    # set fonts
    # TODO leave this here, but commented so we can see how to do it
    # properly later.
    #~ Qt::Font.new( font.family, font.point_size * 5 / 6 ).tap do |fnt|
      #~ self.font = fnt
      #~ self.horizontal_header.font = fnt
    #~ end 
    
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
  
  # return a collection of collections of TableIndex objects
  # indicating the indices of the current selection
  def selected_rows
    rows = []
    selection_model.selection.each do |selection_range|
      (selection_range.top..selection_range.bottom).each do |row|
        rows << (selection_range.top_left.column..selection_range.bottom_right.column).map do |col|
          model.create_index( row, col )
        end
      end
    end
    rows
  end
  
  def status_text( msg )
    emit status_text( msg )
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
  
  # set the size of the column from the sample
  def auto_size_column( col, sample )
    self.set_column_width( col, column_size( col, sample ).width )
  end

  def metrics
    @metrics = Qt::FontMetrics.new( font )
  end
  
  # set the size of the column from the string value of the data
  # mostly copied from qheaderview.cpp:2301
  def column_size( col, data )
    opt = Qt::StyleOptionHeader.new
    
    # fetch font size
    opt.fontMetrics = metrics
    opt.rect = opt.fontMetrics.bounding_rect( data.to_s )
    
    # set data
    opt.text = data.to_s
    
    opt.section =
    case
      when col == 0
        Qt::StyleOptionHeader::Beginning
        
      when col > 0 && col < model.fields.size - 1
        Qt::StyleOptionHeader::Middle
        
      when col == model.fields.size - 1
        Qt::StyleOptionHeader::End
    end
    
    size = Qt::Size.new( opt.fontMetrics.width( data.to_s ), opt.fontMetrics.height )
    
    # final parameter could be header section
    style.sizeFromContents( Qt::Style::CT_HeaderSection, opt, size )
  end
  
  # make sure row size is correct
  # show error messages for data
  def setModel( model )
    # must do this otherwise model gets garbage collected
    @model = model
    
    # make sure we get nice spacing
    vertical_header.default_section_size = metrics.height
    vertical_header.minimum_section_size = metrics.height
    super
    
    # set delegates
    model.fields.each_with_index do |field, index|
      set_item_delegate_for_column( index, field.delegate )
    end
    
    # data errors
    model.connect( SIGNAL( 'data_error(QModelIndex, QVariant, QString)' ) ) do |index,variant,msg|
      show_error( "Incorrect value '#{variant.value}' entered for field [#{index.attribute.to_s}].\nMessage was: #{msg}" )
    end
  end
  
  def show_error( msg )
    error_message = Qt::ErrorMessage.new( self )
    error_message.show_message( msg )
    error_message.show
  end
  
  # and override this because the Qt bindings don't call
  # setModel otherwise
  def model=( model )
    setModel( model )
    resize_columns
  end
  
  def moveCursor( cursor_action, modifiers )
    # TODO use this as a preload indicator
    super
  end

  # returns the Qt::MessageBox
  def confirm_dialog( question, title )
    msg = Qt::MessageBox.new(
      Qt::MessageBox::Question,
      title,
      question,
      Qt::MessageBox::Yes | Qt::MessageBox::No,
      self
    )
    msg.exec
    msg
  end
  
  def keyPressEvent( event )
    handle_key_press( event )
    super
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
  rescue
    puts $!.message
    puts $!.backtrace
    show_error "Error saving data from #{editor.inspect}: #{$!.message}"
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
      raise RuntimeError, "#{model.entity_view.class.name}.#{model_index.field.id}: #{e.message}", e.backtrace
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
  # TODO put it in a module and add the module when the tab widgets
  # are being built.
  def with_table_view( entity_model_or_view, &block )
    tv = find_table_view( entity_model_or_view )
    yield( tv ) unless tv.nil?
  end
  
  # make this window visible if it's in a TabWidget
  # TODO doesn't really belong here because TableView will not always
  # be in a TabWidget context. Should emit a signal which is a request to raise
  def raise_widget
    # the tab's parent is a StackedWiget, and its parent is TabWidget
    tab_widget = parent.parent
    tab_widget.current_widget = self if tab_widget.class == Qt::TabWidget
  end

  def busy_cursor( &block )
    override_cursor( Qt::BusyCursor, &block )
  end

end

end
