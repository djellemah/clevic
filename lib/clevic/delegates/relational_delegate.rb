require 'clevic/delegates/combo_delegate'
require 'clevic/dataset_roller.rb'

module Clevic

# Display a collection of possible related entities in the combo box.
# TODO this should be a module
class RelationalDelegate
  def needs_combo?
    dataset.count > 0
  end
  
  def empty_set_message
    "There must be records in #{field.related_class.name.humanize} for this field to be editable."
  end
  
  def population
    # dataset contains the set of all possible related entities,
    
    # dataset is defined in Delegate
    # entity is set in init_component
    # field and entity are used by FieldValuer
    
    # FIXME don't really need this if clause
    # because attribute_value is what we're interested in
    # and actually entity won't ever be nil because
    # the row containing this field won't ever have a nil entity.
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
      dataset.all.with do |values|
        # make sure there's only one instance of the current value,
        # and make sure it's at the top of the list
        values.delete( attribute_value )
        values.unshift( attribute_value )
      end
    end
  end
  
  # don't allow new values
  def restricted?; true; end

protected
  # Return an instance of the ORM dataset,
  # right now that's Sequel::Dataset.
  # This exists because convincing this functionality to
  # coexist in the same method as dataset would be tricky.
  def dataset
    unless field.find_options.empty?
      require 'clevic/ar_methods'
      field.related_class.plugin :ar_methods
      field.related_class.translate( field.find_options )
    else
      field.dataset_roller.dataset
    end
  end
  
end

end
