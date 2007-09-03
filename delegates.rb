# To emit focus out signals, because ComboBox stupidly doesn't.
class EntryDelegate < Qt::ItemDelegate
  
  def initialize( parent, field_name, editor_class )
    super( parent )
    @field_name = field_name
    @editor_class = editor_class
  end
  
  def createEditor( parent_widget, style_option_view_item, model_index )
    @editor_class.new( parent_widget )
  end
  
  def setEditorData( editor, model_index )
    editor.value = model_index.gui_value
  end
  
  def setModelData( editor, abstract_item_model, model_index )
    model_index.gui_value = editor.value
  end
  
  def updateEditorGeometry( editor, style_option_view_item, model_index )
    # figure out where to put the editor widget, taking into
    # account the sizes of the headers
    rect = style_option_view_item.rect
    rect.set_width( editor.size_hint.width )
    editor.set_geometry( rect )
  end
end

class ComboDelegate < Qt::ItemDelegate
  
  def initialize( parent )
    super( parent )
    
    # make sure the values are correctly saved on exit
    self.connect( SIGNAL( 'closeEditor ( QWidget*, QAbstractItemDelegate::EndEditHint )' ) ) do |editor, hint|
      #~ puts "close editor #{editor.inspect} with #{hint}: #{hint_string(hint)}"
      close_editor( editor, hint )
    end
  end
  
  def hint_string( hint )
    hs = String.new
    Qt::AbstractItemDelegate.constants.each do |x|
      hs = x if eval( "Qt::AbstractItemDelegate::#{x}.to_i" ) == hint.to_i
    end
    hs
  end
    
  def dump_editor_state( editor )
    if false
			puts "editor.completer.completion_count: #{editor.completer.completion_count}"
			puts "editor.completer.current_completion: #{editor.completer.current_completion}"
			puts "editor.find_text( editor.completer.current_completion ): #{editor.find_text( editor.completer.current_completion )}"
			puts "editor.current_text: #{editor.current_text}"
			puts "editor.count: #{editor.count}"
			puts "editor.completer.current_row: #{editor.completer.current_row}"
			#~ puts ": #{}"
      puts
		end
  end
  
  # open the combo box, just like if f4 was pressed
  def open
    @editor.show_popup
  end
  
  # descendants should override this to fill the combo box
  # list with values
  def populate( editor, model_index )
  end
  
  # This catches the event that begins the edit process.
  # Not used at the moment
  def editorEvent ( event, model, style_option_view_item, model_index ) 
    super
  end
  
  # Create a ComboBox and fill it with the possible values
  def createEditor( parent_widget, style_option_view_item, model_index )
    # save these for later
    @current_index = model_index
    @old_value = model_index.attribute_value
    
    @editor = Qt::ComboBox.new( parent )
    
    # subclasses fill in the rest of the entries
    populate( @editor, model_index )
    
    # create a nil entry
    if ( @editor.find_data( nil.to_variant ) == -1 )
      @editor.add_item( '', nil.to_variant )
    end
    
    # allow prefix matching from the keyboard
    @editor.editable = true
    #~ @editor.completer.model_sorting = Qt::Completer::CaseInsensitivelySortedModel
    
    @editor
  end
  
  # make sure tab and backtab save data
  def eventFilter( editor, event )
    if event.class == Qt::KeyEvent
      if event.tab? || event.backtab?
        emit closeEditor( editor, Qt::AbstractItemDelegate::SubmitModelCache )
      end
    end
    super
  end

  def close_editor( editor, hint )
  end

  def updateEditorGeometry( editor, style_option_view_item, model_index )
    # figure out where to put the editor widget, taking into
    # account the sizes of the headers
    rect = style_option_view_item.rect
    horizontal_header_rect = parent.horizontal_header.rect
    vertical_header_rect = parent.vertical_header.rect
    rect.translate( vertical_header_rect.width + 1, horizontal_header_rect.height + 1 )
    
    # ask the editor for how much space it wants
    rect.set_width( editor.size_hint.width )
    
    editor.set_geometry( rect )
  end

end

# provide a list of all values in this field
# and allow new values to be entered
class DistinctDelegate < ComboDelegate
  
  def initialize( parent, attribute, options )
    @ar_model = parent.model.collection[0].class
    @attribute = attribute
    @options = options
    super( parent )
  end
  
  def populate( editor, model_index )
    # we only use the first column, so use the second
    # column to sort by, since SQL requires the order by clause
    # to be in the select list where distinct is involved
    rs = @ar_model.connection.execute <<-EOF
      select distinct #{@attribute.to_s}, lower(#{@attribute.to_s})
      from #{@ar_model.table_name}
      order by lower(#{@attribute.to_s})
    EOF
    rs.rows.each do |row|
      editor.add_item( row[0], row[0].to_variant )
    end
  end
  
  # send data to the editor
  def setEditorData( editor, model_index )
    editor.current_index = editor.find_data( model_index.attribute_value.to_variant )
    editor.line_edit.select_all
  end
  
  # save the object in the model entity relationship
  def setModelData( editor, abstract_item_model, model_index )
    item_data = editor.item_data( editor.current_index )
    model_index.attribute_value = item_data.value
  end
  
  # save the value in the field, depending on what exit happened
  def close_editor( editor, hint )
    dump_editor_state( editor )
    
		case hint
      when Qt::AbstractItemDelegate::SubmitModelCache
      if editor.completer.current_row == -1
        @current_index.attribute_value = editor.current_text
      else
        @current_index.attribute_value = editor.completer.current_completion
      end
      
      when Qt::AbstractItemDelegate::RevertModelCache
        @current_index.attribute_value = @old_value
    end
  end

end

# To edit a relation from an id and display a list of relevant entries
# attribute_path is the full dotted path to get from the entity in the
# model to the values displayed in the combo box.
# the ids of the ActiveRecord models are stored in the item data
# and the item text is fetched from them using attribute_path
class RelationalDelegate < ComboDelegate

  def initialize( parent, attribute_path, options )
    attributes = attribute_path.split(/\./)
    @model_class = ( options[:class_name] || attributes[0].classify ).constantize
    @attribute_path = attributes[1..-1].join('.')
    @options = options.clone
    @options.delete :class_name
    super( parent )
  end
  
  def populate( editor, model_index )
    # add set of all possible related entities
    @model_class.find( :all, @options ).each do |x|
      editor.add_item( x[@attribute_path], x.id.to_variant )
    end
    
    # always add the current selection, if it isn't already there
    # and it makes sense. This is to make sure that if the list
    # is filtered, we always have the current value if the filter
    # excludes it
    if !model_index.nil?
      item = model_index.attribute_value
      if item
        item_index = editor.find_data( item.id.to_variant )
        if item_index == -1
          editor.add_item( item[@attribute_path], item.id.to_variant )
        end
      end
    end
  end
  
  # send data to the editor
  def setEditorData( editor, model_index )
    editor.current_index = editor.find_data( model_index.attribute_value.id.to_variant )
    editor.line_edit.select_all
  end
  
  # save the object in the model entity relationship
  def setModelData( editor, abstract_item_model, model_index )
    # fetch record id from editor item_data
    item_data = editor.item_data( editor.current_index )
    if item_data.valid?
      # get the entity it refers to, if there is one
      obj = @model_class.find_by_id( item_data.to_int )
      unless obj.nil?
        # save the belongs_to entity in the row model entity
        model_index.attribute_value = obj
      end
    else
      model_index.attribute_value = nil
    end
  end
  
  # this doesn't save the entity to the db, it just
  # manipulates values in the entity
  def close_editor( editor, hint )
		dump_editor_state( editor )
		case hint
      when Qt::AbstractItemDelegate::SubmitModelCache
        if editor.completer.current_row == -1
          @current_index.attribute_value = nil
        else
          editor.set_current_index( editor.find_text( editor.completer.current_completion ) )
          setModelData( editor, parent.model, parent.current_index )
        end
        
      when Qt::AbstractItemDelegate::RevertModelCache
        @current_index.attribute_value = @old_value
    end
	end

end
