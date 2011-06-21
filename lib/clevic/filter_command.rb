module Clevic
  class FilterCommand
    # filter_block will be passed a Dataset to filter.
    # filter_message will be displayed.
    def initialize( table_view, message = nil, &filter_block )
      @table_view = table_view
      @message = message || 'filtered'
      @filter_block = filter_block
    end
    
    attr_reader :message
    
    # Do the filtering. Return true if successful, false otherwise.
    def doit
      # store current dataset
      @previous_dataset = @table_view.model.cache_table.dataset
      
      # store auto_new
      @auto_new = @table_view.model.auto_new
      
      # reload cache table with new conditions
      @table_view.model.auto_new = false
      @table_view.model.reload_data( &@filter_block )
      true
    rescue Exception => e
      puts
      puts e.message
      puts e.backtrace
      false
    end
    
    def undo
      # restore auto_new
      @table_view.model.auto_new = @auto_new
      
      # reload cache table with stored AR conditions
      @table_view.model.reload_data( @previous_dataset )
    end
  end
end
