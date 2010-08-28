require 'clevic/swing/delegate'

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
    unless find_options[:conditions].nil?
      find_options[:conditions].gsub!( /true/, field.related_class.adaptor.quoted_true )
      find_options[:conditions].gsub!( /false/, field.related_class.adaptor.quoted_false )
    end
  end
  
  # use the Clevic::ComboBox class because JCombobox is remarkably stupid
  # about far too many things.
  def combo_class
    ComboBox
  end
  
  def needs_combo?
    field.related_class.adaptor.count( :conditions => find_options[:conditions] ) > 0
  end
  
  def empty_set_message
    "There must be records in #{field.related_class.name.humanize} for this field to be editable."
  end
  
  def population
    # add set of all possible related entities
    field.related_class.adaptor.find( :all, find_options )
  end
  
  # don't allow new values
  def restricted?
    true
  end
end

end
