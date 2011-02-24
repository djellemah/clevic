require 'clevic/swing/combo_delegate'

module Clevic

# Provide a list of all values in this field,
# and allow new values to be entered.
# :frequency can be set as an option. Boolean. If it's true
# the options are sorted in order of most frequently used first.
class DistinctDelegate < ComboDelegate
  # strings are stored in the model
  def display_for( model_value )
    model_value
  end
end

end

require 'clevic/delegates/distinct_delegate'
