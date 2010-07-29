Component = java.awt.Component
class Component
  def <<( obj )
    case obj
    when Clevic::Separator
      add_separator
    
    when Clevic::Action
      add obj.menu_item
    
    when String
      add obj.to_java_string
    
    else
      add obj
    end
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

JObject = java.lang.Object
class JObject
  def const_lookup( integer )
    self.class.constants.select {|x| eval( "self.class::#{x}" ) == integer }
  end
end

KeyEvent = java.awt.event.KeyEvent
class KeyEvent
  def alt?
    modifiers & self.class::ALT_MASK != 0
  end
  
  def ctrl?
    modifiers & self.class::CTRL_MASK != 0
  end
  
  def meta?
    modifiers & self.class::META_MASK != 0
  end
  
  def self.function_keys
    @function_keys ||= (1..24).map{|i| eval( "VK_F#{i}" ) }
  end
  
  def fx?
    self.class.function_keys.include?( key_code )
  end
  
  def shift?
    modifiers & self.class::SHIFT_MASK != 0
  end
  
  def plain?
    modifiers == 0
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
