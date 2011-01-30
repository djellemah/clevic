require 'clevic/field_valuer.rb'

module Clevic

# This has both a field and an entity, so it's a perfect candidate
# for including FieldValuer, which it does.
class Delegate
  include FieldValuer

  def initialize( field )
    super()
    @field = field
  end
  
  # This is the ORM entity instance for which this delegate
  # is editing a single field. It needs to be the entire entity
  # so we can set the edited field value on it.
  attr_accessor :entity
  
  # The parent widget of this delegate / this delegate's widget
  attr_accessor :parent
  
  # the Clevic::Field instance which this delegate edits.
  attr_reader :field
  
  def attribute
    field.attribute
  end
  
  def entity_class
    field.entity_class
  end
  
  # TODO use DatasetRoller here
  def dataset
    require 'clevic/ar_methods'
    field.related_class.plugin :ar_methods
    field.related_class.translate( field.find_options )
  end
  
  # assume this is not a combo delegate. That will come later.
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
