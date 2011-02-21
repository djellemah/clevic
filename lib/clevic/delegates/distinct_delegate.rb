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
  
  # TODO move away from ar_methods. Partly done.
  # TODO ordering by either recentness, or frequency. OR both.
  # TODO make sure nil is in the list. And the current item is at the top.
  # TODO and the current item is in the list, even if it's older
  # we only use the first column, so use the second
  # column to sort by, since SQL requires the order by clause
  # to be in the select list where distinct is involved
  def dataset
    base_dataset =
    unless field.find_options.empty?
      puts "conditions and order are deprecated. Use dataset instead."
      require 'clevic/ar_methods'
      field.entity_class.plugin :ar_methods
      field.entity_class.translate( field.find_options )
    else
      field.dataset_roller.dataset
    end
    
    # now pull out the field and the distinct values
    base_dataset. \
      distinct. \
      select( field.attribute ). \
      order( field.attribute ). \
      naked
  end
  
  def population
    dataset.map( field.attribute )
  end
  
end

end
