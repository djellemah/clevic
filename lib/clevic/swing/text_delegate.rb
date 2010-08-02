require 'clevic/swing/delegate'

module Clevic

  class TextDelegate < Delegate
    def init_component
      editor.text = edit_value
      editor.select_all
    end
    
    def editor
      @editor ||= javax.swing.JTextField.new
    end
    
    # TODO maybe full_edit should open in a separate window?
    
    def value
      editor.text
    end
    
    def minimal_edit
      editor.select_all
    end
  end

end
