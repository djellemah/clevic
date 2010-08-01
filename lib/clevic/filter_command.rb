module Clevic
  class FilterCommand
    def initialize( table_view, filter_indexes, filter_conditions )
      @table_view = table_view
      @filter_conditions = filter_conditions
      @filter_indexes = filter_indexes
      
      # Better make the status message now, before the indexes become invalid
      @status_message =
      "Filtered on #{filter_indexes.first.field.label} = #{filter_indexes.first.display_value}"
    end
    
    # Do the filtering. Return true if successful, false otherwise.
    def doit
      begin
        # store current AR conditions
        @stored_conditions = @table_view.model.cache_table.find_options
        
        # store auto_new
        @auto_new = @table_view.model.auto_new
        
        # reload cache table with new conditions
        @table_view.model.auto_new = false
        @table_view.model.reload_data( @filter_conditions )
      rescue Exception => e
        puts
        puts e.message
        puts e.backtrace
        false
      end
      true
    end
    
    def undo
      # restore auto_new
      @table_view.model.auto_new = @auto_new
      
      # reload cache table with stored AR conditions
      @table_view.model.reload_data( @stored_conditions )
    end
    
    # return a message based on the conditions
    def status_message
      @status_message
    end
  end
end
