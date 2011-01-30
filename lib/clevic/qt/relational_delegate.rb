require 'clevic/qt/combo_delegate.rb'

module Clevic

# Edit a relation from an id and display a list of relevant entries.
#
# attribute is the method to call on the row entity to retrieve the related object.
# 
# The ids of the model objects are stored in the item data
# and the item text is fetched from them using attribute_path.
class RelationalDelegate < ComboDelegate
  def needs_combo?
    dataset.count > 0
  end
  
  def empty_set_message
    "There must be records in #{field.related_class.name.humanize} for this field to be editable."
  end

  def item_to_editor( item )
    [ field.transform_attribute( item ), item.pk.to_variant ]
  end
  
  def editor_to_item( data )
    entity.related_class[ data ]
  end
  
  # called by Qt when it wants to give the delegate an index to edit
  def setEditorData( editor_widget, model_index )
    if is_combo?( editor_widget )
      unless model_index.attribute_value.nil?
        editor_widget.selected_item = model_index.attribute_value
      end
      editor_widget.line_edit.andand.select_all
    end
  end
  
  # return an entity object, given a text selection
  def translate_from_editor_text( editor_widget, text )
    item_index = editor_widget.find_text( text )
    
    # fetch record id from editor_widget item_data
    item_data = editor_widget.item_data( item_index )
    if item_data.valid?
      # get the entity it refers to, if there is one
      # return nil if nil was passed or the entity wasn't found
      field.related_class[ item_data.to_int ]
    end
  end
  
end

end

require 'clevic/delegates/relational_delegate.rb'
