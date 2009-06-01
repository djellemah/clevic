require 'clevic/item_delegate.rb'

module Clevic

  class TextDelegate < ItemDelegate
    
    # Doesn't do anything useful yet, but I'm leaving
    # it here so I don't have to change other code.
    class TextEditor < Qt::TextEdit
    end
    
    # this is overridden in Qt::ItemDelegate, but that
    # always catches the return key. Which we want for text editing.
    # Instead, we use Ctrl-Enter to save the edited text.
    # return true if event is handled, false otherwise
    def eventFilter( object, event )
      if object.class == TextEditor && event.class == Qt::KeyEvent
        retval =
        case
          when event.ctrl? && ( event.enter? || event.return? )
            # close and save
            # copied from QItemDelegate.
            emit commitData( object )
            emit closeEditor( object )
            true
          
          # send an enter or return to the text editor
          when event.enter? || event.return?
            object.event( event )
            true
            
        end
      end
      retval || super
    end
    
    # maybe open in a separate window?
    def full_edit
    end
    
    # Override the Qt method. Create a ComboBox widget and fill it with the possible values.
    def createEditor( parent_widget, style_option_view_item, model_index )
      @editor = TextEditor.new( parent_widget )
      @editor.install_event_filter( self )
    end
    
    # Override the Qt::ItemDelegate method.
    def updateEditorGeometry( editor, style_option_view_item, model_index )
      rect = style_option_view_item.rect
      
      # ask the editor for how much space it wants, and set the editor
      # to that size when it displays in the table
      rect.set_width( [editor.size_hint.width,rect.width].max )
      rect.set_height( editor.size_hint.height )
      editor.set_geometry( rect )
    end

    # Override the Qt method to send data to the editor from the model.
    def setEditorData( editor, model_index )
      editor.plain_text = model_index.gui_value
    end
    
    # Send the data from the editor to the model. The data will
    # be translated by translate_from_editor_text,
    def setModelData( editor, abstract_item_model, model_index )
      model_index.attribute_value = editor.to_plain_text
      emit abstract_item_model.dataChanged( model_index, model_index )
    end

  end

end
