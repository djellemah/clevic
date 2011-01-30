require 'clevic/delegates/combo_delegate'

module Clevic

# Display a collection of possible related entities in the combo box.
# TODO this should be a module
class RelationalDelegate
  def population
    # dataset contains the set of all possible related entities,
    
    # dataset is defined in Delegate
    # entity is set in init_component
    # field and entity are used by FieldValuer
    
    if entity.nil?
      dataset
    else
      # including the current entity.
      # Could also use
      #  dataset.or( entity_class.primary_key => entity_key.pk )
      # but that would put current entity in the list somewhere
      # other than the top, which seems to be the most sensible
      # place for it. Could also create a special enumerator
      # which gives back the entity first, followed by the dataset.
      
      # FIXME this approach will return the current entity
      # twice in most cases.
      [ attribute_value ] + dataset.all
    end
  end
  
  # don't allow new values
  def restricted?
    true
  end
end

end

