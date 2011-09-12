require 'clevic/qt/combo_delegate.rb'
require 'clevic/qt/simplest_delegate.rb'

module Clevic

class DistinctDelegate < ComboDelegate
  include SimplestDelegate

  # This might be unnecessary.
  def translate_from_editor_text( editor, text )
    text
  end
end

end

require 'clevic/delegates/distinct_delegate.rb'
