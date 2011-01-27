require 'clevic/qt/combo_delegate.rb'

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
  
  def needs_combo?
    field.related_class.adaptor.count( :conditions => find_options[:conditions] ) > 0
  end
  
  def empty_set_message
    "There must be records in #{field.related_class.name.humanize} for this field to be editable."
  end
  
  # add the current item, unless it's already in the combo data
  def populate_current( editor, model_index )
    # always add the current selection, if it isn't already there
    # and it makes sense. This is to make sure that if the list
    # is filtered, we always have the current value if the filter
    # excludes it
    unless model_index.nil?
      item = model_index.attribute_value
      if item
        item_index = editor.find_data( item.id.to_variant )
        if item_index == -1
          add_to_list( editor, model_index, item )
        end
      end
    end
  end

  def populate( editor, model_index )
    # add set of all possible related entities
    field.related_class.find_ar( :all, find_options ).each do |x|
      add_to_list( editor, model_index, x )
    end
  end
  
  def add_to_list( editor, model_index, item )
    editor.add_item( model_index.field.transform_attribute( item ), item.id.to_variant )
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
  
  # return an AR entity object
  def translate_from_editor_text( editor, text )
    item_index = editor.find_text( text )
    
    # fetch record id from editor item_data
    item_data = editor.item_data( item_index )
    if item_data.valid?
      # get the entity it refers to, if there is one
      # use find_by_id so that if it's not found, nil will
      # be returned
      field.related_class[ item_data.to_int ]
    end
  end
  
end

end
