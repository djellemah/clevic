require 'clevic/qt/combo_delegate.rb'

module Clevic

# Provide a list of all values in this field,
# and allow new values to be entered.
# :frequency can be set as an option. Boolean. If it's true
# the options are sorted in order of most frequently used first.
class DistinctDelegate
  
  def needs_combo?
    # works except when there is a null in the column
    dataset.count > 0
  end
  
  # TODO move away from ar_methods
  # TODO ordering by either recentness, or frequency. OR both.
  # we only use the first column, so use the second
  # column to sort by, since SQL requires the order by clause
  # to be in the select list where distinct is involved
  #~ entity_class.adaptor.attribute_list( attribute, model_index.attribute_value, field.description, field.frequency, find_options ) do |row|
    #~ value = row[attribute]
    #~ editor.add_item( value, value.to_variant )
  #~ end
  def dataset
    require 'clevic/ar_methods'
    field.entity_class.plugin :ar_methods
    field.entity_class. \
      translate( field.find_options ). \
      distinct. \
      select( field.attribute ). \
      naked
  end
  
  def population
    dataset.map( field.attribute )
  end
  
end

end
