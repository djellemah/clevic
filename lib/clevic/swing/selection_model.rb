class Array
  def sparse
    Hash[ *(first..last).map do |index|
      [index, include?( index ) ]
    end.flatten ]
  end
end

module Clevic

=begin
QItemSelectionRange contains information about a range of selected items in a 
model. A range of items is a contiguous array of model items, extending to 
cover a number of adjacent rows and columns with a common parent item; this 
can be visualized as a two-dimensional block of cells in a table

file:///usr/share/doc/qt-4.6.2/html/qitemselectionrange.html#details
=end
class SelectionRange
  def height
  end
  
  def width
  end
end

class SelectionModel
  def initialize( table_view )
    @table_view = table_view 
  end
  
  def jtable
    @table_view.jtable
  end
  
  # return a collection of selection ranges
  def ranges
    first = jtable.selected_rows.first
    last = jtable.selected_rows.last
    rows = jtable.selected_rows
    
    jtable.selected_rows.each_with_index do |row_index,index|
      jtable.selected_columns.each do |column_index|
        indexes << SwingTableIndex.new( model, row_index, column_index )
      end
    end
  end
  
  def single_cell?
    jtable.selected_row_count == 1 && jtable.selected_column_count == 1
  end
  
  def row_indexes
    jtable.selected_rows.to_a
  end
  
  def clear
    jtable.clear_selection
  end
  
  # return the full set of selected indexes, ordered
  # by row then column
  def selected_indexes
    indexes = []
    jtable.selected_rows.each do |row_index|
      jtable.selected_columns.each do |column_index|
        indexes << SwingTableIndex.new( model, row_index, column_index )
      end
    end
    indexes
  end
end

end
