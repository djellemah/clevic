require 'clevic/action_builder.rb'
require 'clevic/swing/action.rb'
require 'clevic/swing/extensions.rb'

require 'changes'

module Clevic

module ActionBuilder
  # Create a new separator and add a new separator.
  def separator
    Separator.new.tap do |action|
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
        action_triggered do
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
