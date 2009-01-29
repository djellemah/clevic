module Clevic

  # This is created by Clevic::Record to act as a default
  # view for an ActiveRecord::Base descendant that has
  # an embedded UI definition.
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
      if self.class.define_ui_block.nil?
        # use the define_ui from Clevic::View to build a default UI
        super
      else
        # use the provided block
        model_builder( &self.class.define_ui_block )
      end
    end
    
    def title
      @title ||= entity_class.name.demodulize.tableize.humanize
    end

    def define_actions( table_view, action_builder )
      if entity_class.respond_to?( :actions )
        puts "Deprecated: #{entity_class.name}.actions( table_view, action_builder ). Use define_actions( table_view, action_builder ) instead."
        entity_class.actions( table_view, action_builder )
      elsif entity_class.respond_to?( :define_actions )
        entity_class.define_actions( table_view, action_builder )
      end
    end
    
    def notify_data_changed( table_view, top_left_model_index, bottom_right_model_index )
      if entity_class.respond_to?( :data_changed )
        puts "Deprecated: #{entity_class.name}.data_changed( top_left, bottom_right, table_view ). Use notify_data_changed( table_view, top_left_model_index, bottom_right_model_index ) instead."
        entity_class.data_changed( top_left_model_index, bottom_right_model_index, table_view )
      elsif entity_class.respond_to?( :notify_data_changed )
        entity_class.notify_data_changed( table_view, top_left_model_index, bottom_right_model_index )
      end
    end
    
    def notify_key_press( table_view, key_press_event, current_model_index )
      if entity_class.respond_to?( :key_press_event )
        puts "Deprecated: #{entity_class.name}.key_press_event( key_press_event, current_model_index, table_view ). Use notify_key_press( table_view, key_press_event, current_model_index ) instead."
        entity_class.key_press_event( key_press_event, current_model_index, table_view )
      elsif entity_class.respond_to?( :notify_key_press )
        entity_class.notify_key_press( table_view, key_press_event, current_model_index )
      end
    end
  end
  
end
