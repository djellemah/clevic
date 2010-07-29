JObject = java.lang.Object
class JObject
  def const_lookup( integer )
    self.class.constants.select {|x| eval( "self.class::#{x}" ) == integer }
  end
end

TableModelEvent = javax.swing.event.TableModelEvent
class TableModelEvent
  def inspect
    "#<#{first_row..last_row}, #{column}, #{const_lookup( type )} >"
  end
  
  def updated?
    type == self.class::UPDATE
  end

  def deleted?
    type == self.class::DELETE
  end

  def inserted?
    type == self.class::INSERT
  end
  
  # returns true if this is a notification to update all
  # rows, ie a fireTableDataChanged() was called
  def all_rows?
    first_row == 0 && last_row == java.lang.Integer::MAX_VALUE
  end
end

JTabbedPane = javax.swing.JTabbedPane
class JTabbedPane
  include Enumerable
  
  def each
    (0...count).each do |index|
      yield getComponentAt( index )
    end
  end
  
  def count
    getTabCount
  end
  
  def current=( component )
    self.selected_component = component
  end
end
