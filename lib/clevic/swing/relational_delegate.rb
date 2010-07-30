require 'clevic/swing/delegate'

JComboBox = javax.swing.JComboBox
class JComboBox
  def << ( value )
    model.addElement( value )
  end
  
  def each
    (0...model.size).each do |i|
      yield model.getElementAt( i )
    end
  end
  
  include Enumerable
end

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
    entity_class.adaptor.find( :all, find_options ).each do |x|
      editor << x
    end
  end
  
  # send data to the editor
  def setEditorData( editor, model_index )
    if is_combo?( editor )
      unless model_index.attribute_value.nil?
        editor.current_index = editor.find_data( model_index.attribute_value.id.to_variant )
      end
      editor.line_edit.select_all
    end
  end
  
  # don't allow new values
  def restricted?
    true
  end
  
  # return an entity object
  def translate_from_editor_text( editor, text )
    item_index = editor.find_text( text )
    
    # fetch record id from editor item_data
    item_data = editor.item_data( item_index )
    if item_data.valid?
      # get the entity it refers to, if there is one
      # use find_by_id so that if it's not found, nil will
      # be returned
      entity_class.adaptor.find( item_data.to_int )
    end
  end
  
end

end
