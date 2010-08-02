require 'clevic/swing/delegate'

module Clevic

  class BooleanDelegate < Delegate
    def init_component
      editor.selected = attribute_value
    end
    
    def editor
      @editor ||= javax.swing.JCheckBox.new
    end
    
    def value
      editor.selected
    end
  end

end
