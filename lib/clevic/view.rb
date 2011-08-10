require 'set'
require 'clevic/model_builder.rb'

module Clevic
  # This contains the definition of a particular view of an entity.
  # See Clevic::ModelBuilder.
  class View

    class << self
      def define_ui_block( &block )
        @define_ui_block ||= block
      end

      def order
        @order ||= []
      end

      # sometimes order has duplicates. So this is all unique
      # defined views in order of definition, or as specified.
      def views
        order.uniq
      end

      def []( view_name )
        order.find do |view|
          view.name =~ /#{view_name.to_s}/i
        end
      end

      # Handle situations where the array passed to 
      # Clevic::View.order has entity_class
      # objects in it. In other words, if there is one, pass back it's
      # default view class rather than the entity_class
      def order=( array )
        @order = array.map do |x|
          if x.ancestors.include?( Clevic.base_entity_class )
            x.default_view_class
          else
            x
          end
        end
      end

      def entity_class( *args )
        if args.size == 0
          @entity_class || raise( "entity_class not specified for #{name}" )
        else
          self.entity_class = args.first
        end
      end

      def entity_class=( some_class )
        @entity_class = some_class
      end

      def widget_name( *args )
        if args.size == 0
          # the class name by default
          @widget_name || name
        else
          @widget_name = args.first
        end
      end
    end

    # args can be anything that has a writer method. Often this
    # will be entity_class
    # block contains the ModelBuilder DSL
    def initialize( args = {}, &block )
      @define_ui_block = block
      unless args.nil?
        args.each do |key,value|
          self.send( "#{key}=", value )
        end
      end
    end

    # use block from constructor, or class ui block from eg Clevic::Record
    def define_ui_block
      @define_ui_block || self.class.define_ui_block
    end

    # For descendants to override easily
    def entity_class
      @entity_class || self.class.entity_class
    end
    attr_writer :entity_class

    # The title to display, eg in a tab
    def title
      @title || self.class.name
    end
    attr_writer :title

    def fields
      @fields ||= define_ui.fields
    end

    # used by the framework-specific code to name widgets
    def widget_name
      @widget_name || self.class.widget_name
    end

    def model_builder( value = nil, &block )
      if value.nil?
        @model_builder ||= ModelBuilder.new( self )
        @model_builder.exec_ui_block( &block )
      else
        @model_builder
      end
    end
    attr_writer :model_builder

    # return a default UI constructed from model metadata
    def define_ui
      if define_ui_block.nil?
        # use the define_ui from Clevic::View to build a default UI
        model_builder do
          default_ui
        end
      else
        # use the provided block
        model_builder( &define_ui_block )
      end
    end

    # callback for view/model specific actions
    def define_actions( table_view, action_builder )
    end

    # callback for notify 
    def notify_field( table_view, model_index )
      ndc = model_index.field.notify_data_changed
      case ndc
        when Proc
          ndc.call( self, table_view, model_index )

        when Symbol
          send( ndc, table_view, model_index )
      end
    end

    # Define data changed events. Default is to call notify_data_changed
    # for each field in the rectangular area defined by top_left and bottom_right
    # (which are include Clevic::TableIndex)
    def notify_data_changed( table_view, top_left, bottom_right )
      if top_left == bottom_right
        # shortcut to just the one, seeing as it's probably the most common
        notify_field( table_view, top_left )
      else
        # do the entire rectagular area
        (top_left.row..bottom_right.row).each do |row_index|
          (top_left.column..bottom_right.column).each do |column_index|
            model_index = table_view.model.create_index( row_index, column_index )
            notify_field( table_view, model_index )
          end
        end
      end
    end

    # callback for key presses
    def notify_key_press( table_view, key_press_event, current_model_index )
    end

  end
end
