require 'clevic/qt/combo_delegate.rb'

module Clevic

# A Combo box which allows a set of values. May or may not
# be restricted to the set.
# TODO this is the same as DistinctDelegate
class SetDelegate < ComboDelegate
  def translate_from_editor_text( editor, text )
    text
  end
  
  def item_to_editor( item )
    if item.is_a?( Array )
      [ item.last, item.first ]
    else
      [ item, item ]
    end
  end
  
  
  def editor_to_item( data )
    data.value
  end
end

end

require 'clevic/delegates/set_delegate'
