require 'activerecord'

require 'clevic/dirty.rb'

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
    
    def self.included( base )
      base.extend( ClassMethods )
    end
  end

end

module ActiveRecord
  class Base
    include Clevic::Default
  end
end

module Clevic

  # The module for all model-based and UI definitions. Intended
  # to be used to define one UI per DB model. For more complex
  # situations, see Clevic::Table.
  # Clevic::Record automatically keeps track of the order
  # in which UIs are defined, so that tabs can
  # be constructed in that order.
  module Record
    include Default
    
    def entity_class
      self.class.entity_class
    end
    
    def model_builder( &block )
      @model_builder ||= ModelBuilder.new( entity_class )
      @model_builder.exec_ui_block( &block )
    end
    
    @subclass_order = []
    
    def self.models
      @subclass_order
    end
    
    def self.models=( array )
      @subclass_order = array
    end
    
    def self.db_options=( db_options )
      @db_options = db_options
    end
    
    def self.db_options
      @db_options
    end
    
    module ClassMethods
      def define_ui_block
        @define_ui_block
      end
      
      # use this to define UI blocks using the ModelBuilder DSL
      def define_ui( entity_class = self, &block )
        @entity_class = entity_class
        @define_ui_block = block
      end
      
      # default entity_class is self
      def entity_class( *args )
        if args.size == 0
          @entity_class || self
        else
          @entity_class = args.first
        end
      end
    end
    
    def self.included( base )
      base.extend(ClassMethods)

      # keep track of the order in which subclasses are
      # defined, so that can be used as the default ordering
      # of the views. Also keep track of the DbOptions instance
      @subclass_order << base
      
      # DbOptions instance
      db_options = nil
      found = ObjectSpace.each_object( Clevic::DbOptions ){|x| db_options = x}
      @db_options = db_options
    end
  end
  
end
