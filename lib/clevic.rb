# This provides enough to define UIs.

module Clevic
  def self.base_entity_class
    Sequel::Model
  end
end

# TODO should this really be here?
# There are other inflection gems.
require 'active_support/inflector.rb'

require 'clevic/framework'
require 'clevic/sequel_length_validation.rb'
require 'clevic/record.rb'
require 'clevic/view.rb'
require 'clevic/sequel_meta.rb'
require 'clevic/sequel_clevic.rb'
