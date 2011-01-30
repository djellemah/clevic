require 'clevic/qt/combo_delegate.rb'
require 'clevic/qt/simplest_delegate.rb'

module Clevic

# A Combo box which allows a set of values. May or may not
# be restricted to the set.
class SetDelegate < ComboDelegate
  include SimplestDelegate
end

end

require 'clevic/delegates/set_delegate'
