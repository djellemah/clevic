require 'clevic/swing/delegate'

module Clevic

  class EditorScrollPane < javax.swing.JScrollPane
    # work around stupid JTable non-api for setting
    # cell editor component size
    # rectangle is a java.awt.Rectangle
    def setBounds( rectangle )
      height = 100
      newrect = java.awt.Rectangle.new( rectangle.x, rectangle.y, rectangle.width, height )
      super( newrect )
    end
  end
  
  class TextAreaDelegate < Delegate
    # TODO check that Ctrl-VK_ENTER stops editing
    def init_component( cell_editor )
      @cell_editor = cell_editor
      cell_editor.addCellEditorListener do |event|
        puts
      end
      text_component.text = edit_value
      text_component.rows = edit_value.count( "\n" ) + 2
      text_component.select_all
    end
    
    def editor
      @editor ||= EditorScrollPane.new( text_component, javax.swing.ScrollPaneConstants.VERTICAL_SCROLLBAR_ALWAYS, javax.swing.ScrollPaneConstants.HORIZONTAL_SCROLLBAR_ALWAYS )
    end
    
    def text_component
      @text_component ||= javax.swing.JTextArea.new
    end
    
    def value
      text_component.text
    end
    
    def minimal_edit
      text_component.select_all
    end
    
    def needs_pre_selection?
      true
    end
  end

end
