require 'clevic/field_valuer.rb'

module Clevic

class Delegate
  include FieldValuer

  def initialize( field )
    @field = field
  end
  
  attr_accessor :entity, :parent
  
  attr_reader :field
  def attribute
    field.attribute
  end
  
  def entity_class
    field.entity_class
  end
  
  def find_options
    field.find_options
  end
  
  def is_combo?
    false
  end
  
  # change the visual state of the editor to the biggest / most
  # space-consuming it can be. This grew out of combo boxes having
  # a drop-down that can show or hide.
  def full_edit
  end
  
  # change the visual state of the editor to the smallest / least
  # space-consuming it can be. This grew out of combo boxes having
  # a drop-down that can show or hide.
  def minimal_edit
  end
end

end
