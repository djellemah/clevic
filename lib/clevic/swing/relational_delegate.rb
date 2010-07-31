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
      find_options[:conditions].gsub!( /true/, entity_class.adaptor.quoted_true )
      find_options[:conditions].gsub!( /false/, entity_class.adaptor.quoted_false )
    end
  end
  
  def entity_class
    @entity_class ||= ( field.class_name || field.attribute.to_s.classify ).constantize
  end
  
  def needs_combo?
    entity_class.adaptor.count( :conditions => find_options[:conditions] ) > 0
  end
  
  def empty_set_message
    "There must be records in #{entity_class.name.humanize} for this field to be editable."
  end
  
  def populate( entity )
    # add set of all possible related entities
    entity_class.adaptor.find( :all, find_options ).each do |instance|
      editor << instance
    end
  end
  
  # don't allow new values
  def restricted?
    true
  end
end

end
