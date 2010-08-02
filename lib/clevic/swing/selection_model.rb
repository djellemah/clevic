module Clevic

=begin
QItemSelectionRange contains information about a range of selected items in a 
model. A range of items is a contiguous array of model items, extending to 
cover a number of adjacent rows and columns with a common parent item; this 
can be visualized as a two-dimensional block of cells in a table

file:///usr/share/doc/qt-4.6.2/html/qitemselectionrange.html#details
=end
class SelectionRange
  def initialize( row_range, column_range )
    @row_range = row_range
    @column_range = column_range
  end
  
  def height
    @row_range.distance
  end
  
  def width
    @column_range.distance
  end
end

class SelectionModel
  def initialize( table_view )
    @table_view = table_view 
  end
  
  attr_reader :table_view
  
  def jtable
    @table_view.jtable
  end
  
  # return a collection of selection ranges
  def ranges
    rv = []
    jtable.selected_rows.group.each do |row_group|
      jtable.selected_columns.group.each do |column_group|
        rv << SelectionRange.new( row_group.range, column_group.range )
      end
    end
    rv
  end
  
  def single_cell?
    jtable.selected_row_count == 1 && jtable.selected_column_count == 1
  end
  
  def selected?( row, column )
    selected_indexes.first.with do |index|
      index.row == row &&
      index.column == column
    end
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
        indexes << table_view.model.create_index( row_index, column_index )
      end
    end
    indexes
  end
end

end
