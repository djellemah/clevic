module Clevic
  class SwingTableIndex
    include TableIndex
    def initialize( model, row, column )
      @model, @row, @column = model, row, column
    end
    attr_accessor :model, :row, :column
    
    def valid?
      row != -1 && column != -1 && model != nil
    end
  end
end

