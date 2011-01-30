module Clevic

class Delegate < Qt::ItemDelegate
  attr_reader :field
  
  # Figure out where to put the editor widget, taking into
  # account the sizes of the headers
  def updateEditorGeometry( editor, style_option_view_item, model_index )
    rect = style_option_view_item.rect
    rect.set_width( [editor.size_hint.width,rect.width].max )
    rect.set_height( editor.size_hint.height )
    editor.set_geometry( rect )
  end

  # This catches the event that begins the edit process.
  def editorEvent ( event, model, style_option_view_item, model_index )
    parent.before_edit_index = model_index
    super
  end

end

end

require 'clevic/delegate'
