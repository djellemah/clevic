module Clevic

# These methods are common between SetDelegate and DistinctDelegate
module SimplestDelegate
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
