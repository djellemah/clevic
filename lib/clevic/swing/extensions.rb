# these two are from
# http://kofno.wordpress.com/2007/05/05/jruby-swingutilitiesinvoke_block_later/
class BlockRunner < java.lang.Thread
  def initialize(&proc)
    @p = proc
  end

  def run
    @p.call
  end
end

unless defined? SwingUtilities
  SwingUtilities = javax.swing.SwingUtilities

  def SwingUtilities.invoke_block_later(&proc)
    r = BlockRunner.new &proc
    invoke_later r
  end
end

module Kernel
  def invoke_later( &block )
    javax.swing.SwingUtilities.invoke_block_later( &block )
  end
end

unless defined? AbstractButton
  AbstractButton = javax.swing.AbstractButton
  class AbstractButton
    def mnemonic=( arg )
      case arg
      when String
        self.setMnemonic( arg.to_char )
      else
        self.setMnemonic( arg )
      end
    end
  end
end

unless defined? CaretEvent
  CaretEvent = javax.swing.event.CaretEvent
  class CaretEvent
    def inspect
      "<CaretEvent dot=#{dot} mark=#{mark} source=#{source}>"
    end
  end
end

unless defined? Component
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
end

unless defined? EventObject
  EventObject = java.util.EventObject
  class EventObject
    def inspect
      if respond_to?( :paramString )
        "<#{self.class.name} #{param_string}>"
      else
        "<#{self.class.name} #{toString}>"
      end
    end
  end
end

unless defined? JComboBox
  JComboBox = javax.swing.JComboBox
  class JComboBox
    def << ( value )
      model.addElement( value )
    end

    def each
      (0...model.size).each do |i|
        yield model.getElementAt( i )
      end
    end

    include Enumerable
  end
end

unless defined? JTabbedPane
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
end

unless defined? JObject
  JObject = java.lang.Object
  class JObject
    # filter_block returns true if the event is to be constantified, false otherwise.
    # the name of the constant will be passed to the block
    def const_lookup( integer, *filter_block )
      self.class.constants.select do |constant_name|
        if eval( "self.class::#{constant_name}" ) == integer
          if block_given?
            yield constant_name
          else
            true
          end
        else
          false
        end
      end
    end
  end
end

unless defined? KeyEvent
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

    def del?
      key_code == VK_DELETE
    end

    def shift?
      modifiers & self.class::SHIFT_MASK != 0
    end

    def plain?
      modifiers == 0
    end

    def esc?
      key_code == VK_ESCAPE
    end

    # a KEY_TYPED event
    def typed?
      getID == self.class::KEY_TYPED
    end

    def inspect
      "<KeyEvent id=#{getID} #{self.class.getKeyText(key_code)} '#{key_char}'>"
    end
  end
end

unless defined? KeyStroke
  KeyStroke = javax.swing.KeyStroke
  class KeyStroke
    def inspect
      toString
    end
  end
end

unless defined? MouseEvent
  MouseEvent = java.awt.event.MouseEvent
  class MouseEvent
    def pressed?
      getID == MOUSE_PRESSED
    end

    def released?
      getID == MOUSE_RELEASED
    end

    def clicked?
      getID == MOUSE_CLICKED
    end

    #~ def inspect
      #~ <<EOF

  #~ button: #{const_lookup(button) {|b| b =~ /BUTTON/} }
  #~ click_count: #{click_count.inspect}
  #~ modifiers_ex_text: #{self.class.getModifiersExText(modifiers)}
  #~ component: #{component.inspect}
#~ EOF
    #~ end
  end
end

unless defined? TableModelEvent
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
end

unless defined? DocumentEvent
  DocumentEvent = javax.swing.event.DocumentEvent
  module DocumentEvent
    def inspect
      "<DocumentEvent type=#{type} offset=#{offset} length=#{length}>"
    end
  end
end


unless defined? ItemEvent
  ItemEvent = java.awt.event.ItemEvent
  class ItemEvent
    def inspect
      "<ItemEvent state=#{const_lookup state_change} ps=#{param_string}>"
    end
  end
end
