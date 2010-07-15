module Clevic

class Delegate
  def initialize( field )
    @field = field
  end
  
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
  
end

end
