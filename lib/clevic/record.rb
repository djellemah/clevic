module Clevic

  # The base class for all Clevic model and UI definitions.
  # minimal definition is like this
  #   class User < Clevic::Record; end
  # This will automatically keep track of the order
  # in which models are defined, so that tabs can
  # be constructed in that order.
  class Record < ActiveRecord::Base
    include ActiveRecord::Dirty
    self.abstract_class = true
    @@subclass_order = []
    
    def self.inherited( subclass )
      @@subclass_order << subclass
      super
    end
    
    def self.models
      @@subclass_order
    end

    def self.models=( array )
      @@subclass_order = array
    end
  end
  
end
