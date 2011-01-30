require 'clevic/qt/combo_delegate.rb'

module Clevic

# Provide a list of all values in this field,
# and allow new values to be entered.
# :frequency can be set as an option. Boolean. If it's true
# the options are sorted in order of most frequently used first.
class DistinctDelegate < ComboDelegate
  
  def needs_combo?
    # works except when there is a null in the column
    dataset.distinct.select( attribute ).count > 0
  end
  
  def population
    # we only use the first column, so use the second
    # column to sort by, since SQL requires the order by clause
    # to be in the select list where distinct is involved
    #~ entity_class.adaptor.attribute_list( attribute, model_index.attribute_value, field.description, field.frequency, find_options ) do |row|
      #~ value = row[attribute]
      #~ editor.add_item( value, value.to_variant )
    #~ end
    dataset.distinct
  end
  
  def translate_from_editor_text( editor, text )
    text
  end
end

end
