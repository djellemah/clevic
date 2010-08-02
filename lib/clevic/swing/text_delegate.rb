require 'clevic/swing/delegate'

module Clevic

  class TextDelegate < Delegate
    def init_component
      editor.text = field.value_for( entity )
    end
    
    def editor
      @editor ||= javax.swing.JTextField.new
    end
    
    # TODO maybe full_edit should open in a separate window?
    
    def value
      editor.text
    end
  end

end
