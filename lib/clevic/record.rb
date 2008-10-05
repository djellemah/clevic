require 'active_record.rb'
require 'active_record/dirty.rb'

module Clevic

  module Default
    module ClassMethods
      def define_ui_block; nil; end

      def post_default_ui_block
        @post_default_ui_block
      end
      
      def post_default_ui( &block )
        @post_default_ui_block = block
      end
    end
    
    def self.included(base)
      base.extend(ClassMethods)
    end
  end

end

module ActiveRecord
  class Base
    include Clevic::Default
  end
end

module Clevic

  # The base class for all Clevic model and UI definitions.
  # minimal definition is like this
  #   class User < Clevic::Record; end
  # Record automatically keeps track of the order
  # in which models are defined, so that tabs can
  # be constructed in that order.
  class Record < ActiveRecord::Base
    self.abstract_class = true
    @@subclass_order = []
    
    def self.define_ui_block
      @define_ui_block
    end
    
    # keep track of the order in which subclasses are
    # defined, so that can be used as the default ordering
    # of the views.
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
    
    # use this to define UI blocks using the ModelBuilder DSL
    def self.define_ui( &block )
      @define_ui_block = block
    end
  end
  
end
