require 'clevic/qt/combo_delegate.rb'
require 'clevic/qt/simplest_delegate.rb'

module Clevic

class DistinctDelegate < ComboDelegate
  include SimplestDelegate
end

end

require 'clevic/delegates/distinct_delegate.rb'
