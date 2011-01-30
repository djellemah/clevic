# This provides enough to define UIs.

module Clevic
  def self.base_entity_class
    Sequel::Model
  end
end

# TODO should this really be here?
# There are other inflection gems.
# JRuby-1.5.2 raises exception if this require has a .rb on the 
require 'active_support/inflector'

require 'clevic/framework'
require 'clevic/sequel_length_validation.rb'
require 'clevic/record.rb'
require 'clevic/view.rb'
require 'clevic/sequel_meta.rb'
require 'clevic/sequel_clevic.rb'
