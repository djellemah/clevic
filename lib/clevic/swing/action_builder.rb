require 'clevic/action_builder.rb'
require 'clevic/swing/extensions.rb'
require 'changes'

module Clevic

# dummy class for creating a menu separator
module Separator
  def menu_item
    self
  end
end

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
  # mnemonic
  def mnemonic( item )
    ix = text.index '&'
    if ix
      item.mnemonic = eval( "java.awt.event.KeyEvent::VK_#{text[ix+1..ix+1].upcase}" )
    end
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
      mnemonic( menu_item )
      menu_item.accelerator = shortcut
      menu_item.tool_tip_text = tool_tip
      menu_item.add_action_listener do |event|
        handler.call( event )
      end
    end
    @menu_item
  end
end

module ActionBuilder
  # Create a new separator and add a new separator.
  def separator
    Object.new.tap do |action|
      action.extend( Separator )
      add_action action
      collect_actions << action
    end
  end
  
  def create_action( &block )
    Action.new( self ).tap( &block )
  end
  
  def create_key_sequence( sequence )
    if sequence.is_a?( javax.swing.KeyStroke )
      sequence
    else
      # munge keystroke to something getKeyStroke recognises
      # file:///usr/share/doc/java-sdk-docs-1.6.0.10/html/api/javax/swing/KeyStroke.html#getKeyStroke%28java.lang.String%29
      # Yes, the space MUST be last in the charset, otherwise Ctrl-" fails
      modifiers = sequence.split( /[-+ ]/ )
      last = modifiers.pop
      
      modifier_mask = modifiers.inject(0) do |mask,value|
        mask | eval( "java.awt.event.InputEvent::#{value.upcase}_DOWN_MASK" )
      end
      
      keystroke =
      if last.length == 1
        javax.swing.KeyStroke.getKeyStroke( java.lang.Character.new( last[0] ), modifier_mask )
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

  # set up the code to be executed when an action is triggered,
  def action_method_or_block( action, options, &block )
    puts "action_method_or_block: #{options.inspect}" if $options[:debug]
    # connect the action to some code
    if options.has_key?( :method )
      action.handler do |event|
        puts "action_method_or_block event: #{event.inspect}" if $options[:debug]
        action_triggered do
          # active is from Qt checkbox-menu-items
          send_args = [ options[:method], options.has_key?( :checkable ) ? action.menu_item.selected? : nil ].compact
          send( *send_args )
        end
      end
    else
      unless block.nil?
        # TODO not sure why triggered is outside here, but not in the method section
        action_triggered do
          action.handler do |event|
            yield( event )
          end
        end
      end
    end
    puts "action.handler: #{action.handler.inspect}" if $options[:debug]
  end
end

end # Clevic
