require 'clevic/table_index.rb'
require 'gather'

module Clevic
  class SwingTableIndex
    include TableIndex
    include Gather
    
    def initialize( model, row, column )
      @model, @row, @column = model, row.to_i, column.to_i
    end
    attr_accessor :model
    property :row, :column
    
    def valid?
      row != -1 && column != -1 && model != nil
    end
    
    def self.invalid
      new( nil, -1, -1 )
    end

    def choppy( *args, &block  )
      return self unless self.valid?
      copied = clone.gather( *args, &block )
      
      # TODO this is mostly shared with Qt
      
      # convert a column name to a column index
      unless copied.column.is_a?( Numeric )
        copied.column = model.field_column( copied.column )
      end
      
      # return an invalid index if it's out of bounds,
      # or the copied index if it's OK.
      if copied.row >= model.row_count || copied.column >= model.column_count
        self.class.invalid
      else
        copied
      end
    end
  end
end
