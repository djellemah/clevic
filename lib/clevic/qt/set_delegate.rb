require 'clevic/qt/item_delegate.rb'

module Clevic

# A Combo box which allows a set of values. May or may not
# be restricted to the set.
class SetDelegate < ComboDelegate
  # options must contain a :set => [ ... ] to specify the set of values.
  def initialize( field )
    raise "RestrictedDelegate must have a :set in options" if field.set.nil?
    super
  end
  
  def needs_combo?
    true
  end
  
  def restricted?
    field.restricted || false
  end
  
  def populate( editor, model_index )
    field.set_for( model_index.entity ).each do |item|
      if item.is_a?( Array )
        # this is a hash-like set, so use key as db value
        # and value as display value
        editor.add_item( item.last, item.first.to_variant )
      else
        editor.add_item( item, item.to_variant )
      end
    end
  end
  
  def createEditor( parent_widget, style_option_view_item, model_index )
    editor = super
    
    # the set is provided, so never insert things
    editor.insert_policy = Qt::ComboBox::NoInsert
    editor
  end
    
end

end
