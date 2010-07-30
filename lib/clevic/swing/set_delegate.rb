require 'clevic/swing/combo_delegate.rb'

module Clevic

# A Combo box which allows a set of values. May or may not
# be restricted to the set.
class SetDelegate < ComboDelegate
  # options must contain a :set => [ ... ] to specify the set of values.
  def initialize( field )
    raise "SetDelegate must have a :set in options" if field.set.nil?
    super
  end
  
  def needs_combo?
    true
  end
  
  def restricted?
    field.restricted || false
  end
  
  def populate( editor, table_index )
    field.set_for( table_index.entity ).each do |item|
      if item.is_a?( Array )
        # this is a hash-like set, so use key as db value
        # and value as display value
        class << item
          def toString; last; end
        end
      else
        class << item
          def toString; self; end
        end
      end
      editor.add_item( item )
    end
  end
end

end
