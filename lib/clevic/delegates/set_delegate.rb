require 'clevic/delegates/combo_delegate.rb'

module Clevic

# A Combo box which allows a set of values. May or may not
# be restricted to the set.
# TODO this should be a module
class SetDelegate
  # options must contain a :set => [ ... ] to specify the set of values.
  def initialize( field )
    raise "SetDelegate must have a :set in options" if field.set.nil?
    super
  end
  
  def needs_combo?
    true
  end
  
  def restricted?
    field.restricted || false
  end
  
  # Items here could either be single values,
  # or two-value arrays (from a hash-like set), so use key as db value
  # and value as display value
  def population
    field.set_for( entity )
  end
end

end
