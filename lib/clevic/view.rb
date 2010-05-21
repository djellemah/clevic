require 'set'
require 'clevic/model_builder.rb'

module Clevic
  # This contains the definition of a particular view of an entity.
  # See Clevic::ModelBuilder.
  class View
    @order = []
    def self.order
      @order
    end
    
    # Handle situations where the array passed to 
    # Clevic::View.order = has ActiveRecord::Base
    # objects in it. In other words, if there is one, pass back it's
    # default view class rather than the ActiveRecord::Base subclass.
    def self.order=( array )
      @order = array.map do |x|
        if x.ancestors.include?( ActiveRecord::Base )
          x.default_view_class
        else
          x
        end
      end
    end
    
    def self.entity_class( *args )
      if args.size == 0
        @entity_class || raise( "entity_class not specified for #{name}" )
      else
        @entity_class = args.first
      end
    end
    
    def self.entity_class=( some_class )
      @entity_class = some_class
    end
    
    def self.widget_name( *args )
      if args.size == 0
        # the class name by default
        @widget_name || name
      else
        @widget_name = args.first
      end
    end
    
    # For descendants to override easily
    def entity_class
      self.class.entity_class
    end
    
    # The title to display, eg in a tab
    def title
      self.class.name
    end
    
    def fields
      @fields ||= define_ui
    end
    
    # used for the Qt object_name when ModelBuilder is constructing a widget
    # here so it can be overridden by descendants
    def widget_name
      self.class.widget_name
    end
    
    def model_builder( &block )
      @model_builder ||= ModelBuilder.new( self )
      @model_builder.exec_ui_block( &block )
    end
    
    # return a default UI constructed from model metadata
    def define_ui
      model_builder do
        default_ui
      end
    end
    
    # define view/model specific actions
    def define_actions( table_view, action_builder )
    end
    
    # notify 
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
    # (which are Qt::ModelIndex instances)
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
    
    # be notified of key presses
    def notify_key_press( table_view, key_press_event, current_model_index )
    end
    
  end
end
