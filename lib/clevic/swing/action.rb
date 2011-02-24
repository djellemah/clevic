require 'gather'

module Clevic

class Action
  include Gather
  property :shortcut, :method, :handler, :tool_tip, :visible
  property :name, :text, :checkable, :enabled
  
  # Needed to enable / disable accelerators on the fly.
  def enabled=( bool )
    # test for @menu_item instead of the method to
    # work around Swing Stupidity. See comments in menu_item.
    menu_item.enabled = bool unless @menu_item.nil?
    @enabled = bool
  end
  
  def initialize( parent, options = {}, &block )
    @parent = parent
    @enabled = true
    
    # work around the Swing Stupidity detailed in enabled=
    gather( options, &block )
  end
  attr_reader :parent, :menu_item
  
  def plain_text
    text.gsub( /&/, '' )
  end
  
  def object_name
    name.to_s
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
      
      # Menu item always enabled, until later.
      # Otherwise it prevents the assignment
      # of an accelerator key. So we have to
      # work around yet another Swing stupidity.
      menu_item.enabled = true
      
      menu_item.text = plain_text
      menu_item.mnemonic = mnemonic if mnemonic
      menu_item.accelerator = parse_shortcut( shortcut ) unless shortcut.nil?
      menu_item.tool_tip_text = tool_tip
      menu_item.add_action_listener do |event|
        handler.call( event )
      end
      
      # Put this at the end so it doesn't interfere with the
      # keystroke assignment Swing Stupidity.
      menu_item.enabled = enabled
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
    
    modifier_mask = modifiers.inject(0) do |mask,value|
      mask |
      if value =~ /ctrl/i
        java.awt.Toolkit.getDefaultToolkit().getMenuShortcutKeyMask()
      else
        eval( "java.awt.event.InputEvent::#{value.upcase}_DOWN_MASK" )
      end
    end
    
    keystroke =
    if last.length == 1
      case last
        # these two seem to break the KeyStroke parsing algorithm
        when "'"
          javax.swing.KeyStroke.getKeyStroke( java.awt.event.KeyEvent::VK_QUOTE, modifier_mask )
          
        when '"'
          javax.swing.KeyStroke.getKeyStroke( java.awt.event.KeyEvent::VK_QUOTE, modifier_mask | java.awt.event.InputEvent::SHIFT_DOWN_MASK )
        
        # the conversion in else doesn't work for these
        when '['
          javax.swing.KeyStroke.getKeyStroke( java.awt.event.KeyEvent::VK_OPEN_BRACKET, modifier_mask )
          
        when ']'
          javax.swing.KeyStroke.getKeyStroke( java.awt.event.KeyEvent::VK_CLOSE_BRACKET, modifier_mask )
          
        when ';'
          javax.swing.KeyStroke.getKeyStroke( java.awt.event.KeyEvent::VK_SEMICOLON, modifier_mask )
          
        else
          keystring = javax.swing.KeyStroke.getKeyStroke( java.lang.Character.new( last.to_char ), modifier_mask ).toString
          puts "keystring: #{keystring.inspect}"
          # have to do this conversion for Mac OS X
          javax.swing.KeyStroke.getKeyStroke( keystring.gsub( /typed/, 'pressed' ) )
      end
    else
      # F keys
      # insert, delete, tab etc
      found = java.awt.event.KeyEvent.constants.grep( /#{last}/i )
      raise "too many options for #{sequence}: #{found.inspect}" if found.size != 1
      javax.swing.KeyStroke.getKeyStroke( eval( "java.awt.event.KeyEvent::#{found.first}" ), modifier_mask )
    end
    puts "keystroke: #{keystroke.inspect}"
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
