require 'clevic/qt/delegate.rb'

module Clevic

  class TextDelegate < Delegate

    # Doesn't do anything useful yet, but I'm leaving
    # it here so I don't have to change other code.
    class TextEditor < Qt::PlainTextEdit
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
      puts "#{self.class.name} full_edit"
    end

    # Override the Qt method
    def createEditor( parent_widget, style_option_view_item, model_index )
      if false && model_index.edit_value.count("\n") == 0
        # futzing about here, really
        @editor = Qt::LineEdit.new( parent_widget )
      else
        @editor = TextEditor.new( parent_widget )
        @editor.install_event_filter( self )
      end
      @editor
    end

    # Override the Qt::ItemDelegate method.
    def updateEditorGeometry( editor, style_option_view_item, model_index )
      rect = Qt::Rect.new( style_option_view_item.rect.top_left, style_option_view_item.rect.size ) 

      # ask the editor for how much space it wants, and set the editor
      # to that size when it displays in the table
      rect.set_width( [editor.size_hint.width,rect.width].max )
      rect.set_height( editor.size_hint.height )

      unless editor.parent.rect.contains( rect )
        # 46 because TableView returns an incorrect bottom.
        # And I can't find out how to get the correct value.
        rect.move_bottom( parent.contents_rect.bottom - 46 )
      end
      editor.set_geometry( rect )
    end

    # Override the Qt method to send data to the editor from the model.
    def setEditorData( editor, model_index )
      editor.plain_text = model_index.edit_value
    end

    # Send the data from the editor to the model. The data will
    # be translated by translate_from_editor_text,
    def setModelData( editor, abstract_item_model, model_index )
      model_index.edit_value = editor.to_plain_text
      abstract_item_model.data_changed( model_index )
    rescue
      abstract_item_model.emit_data_error( model_index, editor.to_plain_text, $!.message )
    end

  end

end
