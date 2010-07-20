require 'clevic/action_builder.rb'
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
  
  def initialize( parent )
    @parent = parent
  end
  attr_reader :parent
  
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
    javax.swing.JMenuItem.new( plain_text ).tap do |item|
      mnemonic( item )
      item.add_action_listener do |event|
        puts "event: #{event.inspect}"
        handler.call( event )
      end
    end
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
      javax.swing.KeyStroke.getKeyStroke( sequence )
    end
  end

  # set up the code to be executed when an action is triggered,
  def action_method_or_block( action, options, &block )
    puts "action_method_or_block: #{options.inspect}"
    # connect the action to some code
    if options.has_key?( :method )
      action.handler do |event|
        puts "action_method_or_block event: #{event.inspect}"
        action_triggered do
          send_args = [ options[:method], options.has_key?( :checkable ) ? active : nil ].compact
          send( *send_args )
        end
      end
    else
      unless block.nil?
        action_triggered do
          action.handler do |event|
            yield( active )
          end
        end
      end
    end
    puts "action.handler: #{action.handler.inspect}"
  end
end

end # Clevic
