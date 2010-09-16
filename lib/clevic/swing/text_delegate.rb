require 'clevic/swing/delegate'

module Clevic

  class TextDelegate < Delegate
    # TODO check that VK_ENTER stops editing
    # TODO JTextArea editor
    def init_component( cell_editor )
      editor.text = edit_value
      editor.select_all
    end
    
    def editor
      @editor ||= javax.swing.JTextField.new.tap do |e|
        e.horizontal_alignment = field.swing_alignment
      end
    end
    
    def value
      editor.text
    end
    
    def minimal_edit
      editor.select_all
    end
    
    def needs_pre_selection?
      true
    end
  end

end
