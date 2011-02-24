module Clevic

  # Tricky, this. Keeps passing on the dataset and
  # lets it build up, but keeps the result.
  # Used in the UI block to make a nice syntax for specifying the dataset.
  class DatasetRoller
    def initialize( original_dataset )
      @rolling_dataset = original_dataset
    end
    
    def dataset
      @rolling_dataset
    end
    
    def method_missing(meth, *args, &block)
      @rolling_dataset = @rolling_dataset.send( meth, *args, &block )
      self
    end
  end
  

end
