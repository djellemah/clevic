module Clevic

class Action
  include Gather
  property :shortcut, :method, :handler, :tool_tip, :visible, :name, :text, :checkable
  
  def initialize( parent, options = {}, &block )
    @parent = parent
    gather( options, &block )
  end
  attr_reader :parent, :menu_item
  
  def plain_text
    text.gsub( /&/, '' )
  end
  
  # find the java.awt.event.KeyEvent::VK constant
  # for the letter after the &. Then set it on the item's
  # mnemonic. Because JMenuItem.setMnemonic won't take a nil
  def mnemonic
    if @mnemonic.nil?
      ix = text.index '&'
      @mnemonic =
      if ix
        eval( "java.awt.event.KeyEvent::VK_#{text[ix+1..ix+1].upcase}" )
      else
        false
      end
    end
    @mnemonic
  end
  
  def menu_item
    if @menu_item.nil?
      @menu_item =
      if checkable
        javax.swing.JCheckBoxMenuItem.new
      else
        javax.swing.JMenuItem.new
      end
      
      menu_item.text = plain_text
      menu_item.mnemonic = mnemonic if mnemonic
      menu_item.accelerator = parse_shortcut( shortcut ) unless shortcut.nil?
      menu_item.tool_tip_text = tool_tip
      menu_item.add_action_listener do |event|
        handler.call( event )
      end
    end
    @menu_item
  end
  
  # parse a Qt-style Ctrl+D shortcut specification
  # and return a javax.swing.KeyStroke
  def parse_shortcut( sequence )
    # munge keystroke to something getKeyStroke recognises
    # file:///usr/share/doc/java-sdk-docs-1.6.0.10/html/api/javax/swing/KeyStroke.html#getKeyStroke%28java.lang.String%29
    # Yes, the space MUST be last in the charset, otherwise Ctrl-" fails
    modifiers = sequence.split( /[-+ ]/ )
    last = modifiers.pop
    
    # ewww
    last_char_code =
    if RUBY_VERSION <= '1.8.6'
      last[0]
    else
      last.bytes.first
    end
    
    modifier_mask = modifiers.inject(0) do |mask,value|
      mask | eval( "java.awt.event.InputEvent::#{value.upcase}_DOWN_MASK" )
    end
    
    keystroke =
    if last.length == 1
      case last
        # these two seem to break the KeyStroke parsing algorithm
        when "'"
          javax.swing.KeyStroke.getKeyStroke( java.awt.event.KeyEvent::VK_QUOTE, modifier_mask )
          
        when '"'
          javax.swing.KeyStroke.getKeyStroke( java.awt.event.KeyEvent::VK_QUOTE, modifier_mask | java.awt.event.InputEvent::SHIFT_DOWN_MASK )
        
        # just grab the character code of the last character in the string
        # TODO this won't work in unicode or utf-8
        else
          javax.swing.KeyStroke.getKeyStroke( java.lang.Character.new( last_char_code ), modifier_mask )
      end
    else
      # F keys
      # insert, delete, tab etc
      found = java.awt.event.KeyEvent.constants.grep( /#{last}/i )
      raise "too many options for #{sequence}: #{found.inspect}" if found.size != 1
      javax.swing.KeyStroke.getKeyStroke( eval( "java.awt.event.KeyEvent::#{found.first}" ), modifier_mask )
    end
    keystroke || raise( "unknown keystroke #{sequence} => #{modifiers.inspect} #{last}" )
  end
end

# dummy class for creating a menu separator
class Separator < Action
  def initialize
    super(nil)
  end
  
  def shortcut
    nil
  end
  
  def menu_item
  end
end

end
