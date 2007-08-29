# To emit focus out signals, because ComboBox stupidly doesn't.
class FocusComboBox < Qt::ComboBox
  signals 'focus_out_signal(QFocusEvent*, QKeyEvent*)'
  def focusOutEvent( event )
    emit focus_out_signal( event, @key_event )
  end

  # make sure we save the last key press, so
  # we know what caused the focus out
  # so we know whether to save the partial completion or not
  def event( ev )
    # ev.type == Qt::Event::KeyPress doesn't work
    @key_event = ev if ev.class == Qt::KeyEvent
    super
  end
end

# To edit a relation from an id and display a list of relevant entries
class RelationalDelegate < Qt::ItemDelegate
  def initialize( parent, model_class, field_name, options )
    @model_class = model_class
    @field_name = field_name
    @options = options
    super( parent )
  end
    
  def createEditor( parent_widget, style_option_view_item, model_index )
    editor = FocusComboBox.new( parent )
    @model_class.find( :all, @options ).each do |x|
      editor.add_item( x[@field_name], x.id.to_variant )
    end
    
    # always add the current selection, if it isn't already there
    # and it makes sense. This is to make sure that if the list
    # is filtered, we always have the current value if the filter
    # excludes it
    row_entity = entity_for_index( model_index )
    if row_entity
      item = row_entity.send( "#{@model_class.name.underscore}" )
      if item
        item_index = editor.find_data( item.id.to_variant )
        if item_index == -1
          editor.add_item( item[@field_name], item.id.to_variant )
        end
      end
    end
    
    # allow prefix matching from the keyboard
    editor.editable = true

    # pressing tab with a completion selects it
    editor.connect( SIGNAL( 'focus_out_signal(QFocusEvent*,QKeyEvent*)' ) ) do |event, key_event|
      # always returns Qt::OtherFocusReason
      #~ if event.reason == Qt::TabFocusReason
      # set the current completion, if there is one. In other
      # words, the key left with a tab (not an escape) and
      # the data has actually changed
      if ( 
        key_event != nil &&
        ( key_event.tab? || key_event.backtab? ) &&
        
        editor.completer.completion_count == 1 &&
        editor.find_text( editor.completer.current_completion ) != -1 &&
        editor.completer.current_completion != editor.current_text
      )
        editor.set_current_index( editor.find_text( editor.completer.current_completion ) )
        # this doesn't work for some reason
        #~ emit commitData( editor )
        setModelData( editor, parent.model, parent.current_index )
      end
    end
    editor
  end
  
  # return the object for this row
  def entity_for_index( model_index )
    model_index.model.collection[model_index.row]
  end
  
  def setEditorData( editor, model_index )
    value = entity_for_index( model_index )
    editor.current_index = editor.find_data( value.send( "#{@model_class.name.underscore}" ).id.to_variant )
    editor.line_edit.select_all
  end
  
  def setModelData( editor, abstract_item_model, model_index )
    # fetch record id from editor item_data
    id = editor.item_data( editor.current_index )
    # get the entity it refers to, if there is one
    obj = @model_class.find_by_id id.to_int
    unless obj.nil?
      # save the belongs_to entity in the row model entity
      entry = entity_for_index( model_index )
      entry.send( "#{@model_class.name.underscore}=", obj )
    end
  end
  
  def updateEditorGeometry( editor, style_option_view_item, model_index )
    # figure out where to put the editor widget, taking into
    # account the sizes of the headers
    rect = style_option_view_item.rect
    horizontal_header_rect = parent.horizontal_header.rect
    vertical_header_rect = parent.vertical_header.rect
    rect.translate( vertical_header_rect.width + 1, horizontal_header_rect.height + 1 )
    
    # allow space for combobox dropdown
    rect.set_width( editor.size_hint.width )
    
    editor.set_geometry( rect )
  end
end
