require 'Qt4'

module Qt
  class KeyEvent
    def inspect
      "<Qt::KeyEvent text=#{text} key=#{key}"
    end
  end
end

module Clevic

class ItemDelegate < Qt::ItemDelegate
  attr_reader :field
  
  def initialize( field )
    raise "field is nil" if field.nil?
    # pass nil as Qt object's parent. Will set parent later.
    super( nil )
    @field = field
  end
  
  def attribute
    field.attribute
  end
  
  def entity_class
    field.entity_class
  end
  
  def find_options
    field.find_options
  end
  
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

  # This is called when one of the EditTriggers is pressed. So
  # it's only good for opening a generic keystroke editor, not
  # a specific one, eg a calendar-style date editor.
  #~ def createEditor( parent_widget, style_option_view_item, model_index )
  #~ end
  
  # Set the data for the given editor widget
  #~ def setEditorData( editor_widget, model_index )
  #~ end
  
  # Set the data for the given model and index from the given
  #~ def setModelData( editor_widget, abstract_item_model, model_index )
  #~ end
  
end

end
