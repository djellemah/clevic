require 'clevic/swing/combo_delegate'

module Clevic

# Edit a relation from an id and display a list of relevant entries.
#
# attribute is the method to call on the row entity to retrieve the related object.
# 
# The ids of the model objects are stored in the item data
# and the item text is fetched from them using attribute_path.
class RelationalDelegate < ComboDelegate
  def initialize( field )
    super
  end
  
  # use the Clevic::ComboBox class because JCombobox is remarkably stupid
  # about far too many things.
  def combo_class
    ComboBox
  end
  
  # don't allow new values
  def restricted?
    true
  end
end

end

require 'clevic/delegates/relational_delegate.rb'
