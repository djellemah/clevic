# This provides enough to define UIs.

module Clevic
  def self.base_entity_class
    Sequel::Model
  end
end

# require 'sequel/core'
Sequel.extension :core_extensions

# for demodulize, tableize, humanize, camelize
require 'sequel'
require 'sequel/extensions/inflector'

require 'clevic/framework'
require 'clevic/sequel_length_validation.rb'
require 'clevic/record.rb'
require 'clevic/view.rb'
require 'clevic/sequel_meta.rb'
require 'clevic/sequel_clevic.rb'
