module Clevic

module ActionBuilder
  # Create a new separator and add a new separator.
  def separator
    Qt::Action.new( parent ) do |action|
      action.separator = true
      add_action action
      collect_actions << action
    end
  end
    
  def create_action( &block )
    Qt::Action.new( parent, &block )
  end
  
  # TODO move this into Action, like the swing adapter
  def create_key_sequence( sequence )
    Qt::KeySequence.new( sequence )
  end

  # set up the code to be executed when an action is triggered,
  def action_method_or_block( qt_action, options, &block )
    signal_name = "triggered(#{options.has_key?( :checkable ) ? 'bool' : ''})"
    
    # connect the action to some code
    if options.has_key?( :method )
      qt_action.connect SIGNAL( signal_name ) do |active|
        action_triggered do
          send_args = [ options[:method], options.has_key?( :checkable ) ? active : nil ].compact
          send( *send_args )
        end
      end
    else
      unless block.nil?
        action_triggered do
          qt_action.connect SIGNAL( signal_name ) do |active|
            yield( active )
          end
        end
      end
    end
  end

end
