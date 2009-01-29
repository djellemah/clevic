require 'clevic/view.rb'
require 'clevic/default_view.rb'

module Clevic

  # include this in ActiveRecord::Base instances to
  # get embedded view definitions. A Default#{model}View
  # class will be created.
  module Record
    # TODO not sure if these are necessary here anymore?
    def self.db_options=( db_options )
      @db_options = db_options
    end
    
    def self.db_options
      @db_options
    end
    
    module ClassMethods
      def default_view_class_name
        "::Clevic::Default#{name.gsub('::','')}View"
      end
      
      #TODO will have to fix modules here
      def create_view_class
        # create the default view class
        # Don't use Class.new because even if you assign
        # the result to a contstant, there are still anonymous classes
        # hanging around, which gives weird results with Clevic::View.subclasses.
        st,line = <<-EOF, __LINE__
          class #{default_view_class_name} < Clevic::DefaultView
            entity_class #{name}
          end
        EOF
        eval st, nil, __FILE__, line
        
        # keep track of the order in which views are
        # defined, so that can be used as the default ordering
        # of the views.
        Clevic::View.order << default_view_class_name.constantize
      end
      
      def default_view_class
        @default_view_class ||= eval default_view_class_name
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

      # DbOptions instance
      db_options = nil
      found = ObjectSpace.each_object( Clevic::DbOptions ){|x| db_options = x}
      @db_options = db_options
    end
  end
  
end
