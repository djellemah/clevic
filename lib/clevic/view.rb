require 'clevic/model_builder.rb'

module Clevic
  class View
    def self.subclasses
      super.select{|x| x !~ /Clevic::DefaultView/}
      super.select{|x| x !~ /Clevic::DefaultView/}
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
    
    # deprecated
    def actions( table_view, action_builder )
    end
    
    # define view/model specific actions
    def define_actions( table_view, action_builder )
      actions( table_view, action_builder )
    end
    
    # deprecated
    def data_changed( top_left, bottom_right, table_view )
    end
    
    # define data changed events
    def notify_data_changed( table_view, top_left_model_index, bottom_right_model_index )
      data_changed( top_left_model_index, bottom_right_model_index, table_view )
    end
    
    # deprecated
    def key_press_event( event, current_index, table_view )
    end
    
    # be notified of key presses
    def notify_key_press( table_view, key_press_event, current_model_index )
      key_press_event( key_press_event, current_model_index, table_view )
    end
    
  end
end

# This needs to handle the following scenarios:

#~ # model classes with embedded view definition
#~ class Position < ActiveRecord::Base
  #~ include Clevic::Record
  
  #~ # with and without parameter
  #~ define_ui do |model_builder|
    #~ model_builder.plain :name
    #~ model_builder.relational :classification
  #~ end

  #~ define_actions do |view, action_builder|
  #~ end
  
#~ end

#~ # model classes defined elsewhere
#~ class Address < ActiveRecord::Base
#~ end

#~ class Address
  #~ define_ui do
    #~ # build the UI from metadata
    #~ default_ui
    
    #~ # tweak the model
    #~ hide :password
  #~ end
#~ end

#~ # A separate view class.
#~ # Use instance methods because we want inheritance
#~ # to work normally.
#~ class View < Clevic::View
  #~ # required
  #~ entity_class Position
  
  #~ # OR
  
  #~ def entity_class
    #~ Position
  #~ end
  
  #~ # optional. Defaults to class.name
  #~ widget_name 'PositionView'
  
  #~ # OR
  
  #~ def widget_name
    #~ 'PositionView'
  #~ end
  
  #~ def define_ui
    #~ model_builder do
      #~ # pull in definition from an entity class.
      #~ # This means finding the ModelBuilder, and copying
      #~ # all relevant information to the context for this block
      #~ # and then doing what's here
      #~ # so maybe it should be model_builder( Position ) do ... end
      #~ include Position
      
      #~ plain :profit
      #~ .
      #~ .
    #~ end
  #~ end
  
  #~ # define view/model specific actions
  #~ def define_actions( table_view, action_builder )
  #~ end
  
  #~ # define data changed events
  #~ def data_changed( top_left, bottom_right, table_view )
  #~ def notify_data_changed( table_view, top_left_model_index, bottom_right_model_index )
  #~ end
  
  #~ # be notified of key presses
  #~ def key_press_event( event, current_index, table_view )
  #~ def notify_key_press( table_view, key_press_event, current_model_index )
  #~ end
  
  #~ # TODO how to define view-specific entity methods?
  #~ # can be included on a model-by-model basis? Too slow?
  #~ # could also get some weird side-effects if there are name clashes.
  #~ module Entity
    #~ def profit
    #~ end
  #~ end
#~ end
  
