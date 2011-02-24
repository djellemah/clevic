require 'clevic/view.rb'
require 'clevic/default_view.rb'

module Clevic

  # include this in Sequel::Model classes to
  # get embedded view definitions. See ModelBuilder.
  #
  # A Clevic::Default#{model}View class will be created. If
  # a define_ui block is not specified in the entity class, 
  # a default UI will be created.
  module Record
    module ClassMethods
      def default_view_class_name
        "::Clevic::Default#{name.gsub('::','')}View"
      end
      
      def create_view_class
        # create the default view class
        # Don't use Class.new because even if you assign
        # the result to a constant, there are still anonymous classes
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
        Clevic::View.order << eval( default_view_class_name )
      end
      
      def default_view_class
        @default_view_class ||= eval( default_view_class_name )
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
    end
  end
  
end
