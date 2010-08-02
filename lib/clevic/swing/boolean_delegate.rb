require 'clevic/swing/delegate'

module Clevic

  class BooleanDelegate < Delegate
    def init_component
      editor.selected = attribute_value
    end
    
    def editor
      @editor ||= javax.swing.JCheckBox.new.tap do |e|
        # TODO this is common to all delegates
        e.horizontal_alignment = field.swing_alignment
      end
    end
    
    def value
      editor.selected
    end
    
    def native
      java.lang.Boolean
    end
  end

end
