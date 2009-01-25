module Clevic
  # Define a table view.
  class Table
    include Record
    
    # must return a ModelBuilder instance
    def define_ui
    end

    def actions( view, action_builder )
    end
    
    def title
      self.class.name
    end
    
    # TODO finish this
    def self.transform( symbol, &block )
      # do something that executes in the context of the model
    end
  end
end
