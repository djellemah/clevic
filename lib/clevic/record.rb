require 'clevic/view.rb'

module Clevic

  class DefaultView < View
    def method_missing( meth, *args, &block )
      if entity_class.respond_to?( meth )
        entity_class.send( meth, *args, &block )
      else
        super
      end
    end
    
    def self.define_ui_block( &block )
      @define_ui_block ||= block
    end
    
    def define_ui
      model_builder( &self.class.define_ui_block )
    end
    
  end
  
  # include this in ActiveRecord::Base instances to
  # get embedded view definitions. The ActiveRecord::Base
  # subclass will then respond to the same methods
  # as a Clevic::View instance, and can be passed to ModelBuilder etc.
  module Record
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
      def default_view_class_name
        "::Default#{name}View"
      end
      
      #TODO will have to fix modules here
      def create_view_class
        # create the default view class
        eval( "#{default_view_class_name} = Class.new( Clevic::DefaultView )" )
        eval( "#{default_view_class_name}.entity_class = #{name}" )
      end
      
      def create_default_view
        @default_view = eval "#{default_view_class_name}.new"
      end
    
      # create a view class. A descendant of DefaultView
      def default_view
        @default_view
      end
      
      def default_view_class
        eval default_view_class_name
      end
      
      # Need to defer the execution of the view definition block
      # until related models have been defined.
      def define_ui( &block )
        default_view_class.define_ui_block( &block )
      end
      
    end
    
    def self.included( base )
      base.extend( ClassMethods )
      
      # create the default view class
      base.create_view_class
      base.create_default_view

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
