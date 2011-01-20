# This provides enough to define UIs.

module Clevic
  def self.base_entity_class
    Sequel::Model
  end
end

require 'clevic/sequel_ar_adapter.rb'
require 'clevic/sequel_length_validation.rb'
require 'clevic/record.rb'
require 'clevic/view.rb'
require 'clevic/sequel_meta.rb'
