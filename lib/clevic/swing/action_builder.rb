require 'clevic/action_builder.rb'
require 'clevic/swing/action.rb'
require 'clevic/swing/extensions.rb'

require 'changes'

module Clevic

# dummy class for creating a menu separator
module Separator
  def menu_item
    self
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
  
  # set up the code to be executed when an action is triggered,
  def action_method_or_block( action, options, &block )
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
  end
end

end # Clevic
