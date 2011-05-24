# This provides enough to define UIs.

module Clevic
  def self.base_entity_class
    Sequel::Model
  end
end

# TODO should this really be here?
# There are other inflection gems.

# for camelize and friends
# TODO JRuby-1.5.2 raises exception if this require has a .rb on the 
require 'sequel/core'
require 'sequel/extensions/inflector'

# for demodulize, tableize, humanize
require 'sequel'
require 'sequel/extensions/inflector'

require 'clevic/framework'
require 'clevic/sequel_length_validation.rb'
require 'clevic/record.rb'
require 'clevic/view.rb'
require 'clevic/sequel_meta.rb'
require 'clevic/sequel_clevic.rb'
