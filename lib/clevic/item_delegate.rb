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
  
  def initialize( parent )
    super
  end
  
  # This catches the event that begins the edit process.
  # Not used at the moment.
  def editorEvent ( event, model, style_option_view_item, model_index )
    if $options[:debug]
      puts "editorEvent"
      puts "event: #{event.inspect}"
      puts "model: #{model.inspect}"
      puts "style_option_view_item: #{style_option_view_item.inspect}"
      puts "model_index: #{model_index.inspect}"
    end
    super
  end
  
  def createEditor( parent_widget, style_option_view_item, model_index )
    puts "model_index.metadata.type: #{model_index.metadata.type.inspect}" if $options[:debug]
    if model_index.metadata.type == :date
      # not going to work here because being triggered by
      # an alphanumeric keystroke (as opposed to F4)
      # will result in the calendar widget being opened.
      #~ Qt::CalendarWidget.new( parent_widget )
      super
    else
      super
    end
  end
  
  #~ def setEditorData( editor, model_index )
    #~ editor.value = model_index.gui_value
  #~ end
  
  #~ def setModelData( editor, abstract_item_model, model_index )
    #~ model_index.gui_value = editor.value
    #~ emit abstract_item_model.dataChanged( model_index, model_index )
  #~ end
  
  def updateEditorGeometry( editor, style_option_view_item, model_index )
    # figure out where to put the editor widget, taking into
    # account the sizes of the headers
    rect = style_option_view_item.rect
    rect.set_width( [editor.size_hint.width,rect.width].max )
    rect.set_height( editor.size_hint.height )
    editor.set_geometry( rect )
  end
end

end
