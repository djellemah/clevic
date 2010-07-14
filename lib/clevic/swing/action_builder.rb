=begin rdoc
This module can be used in an object that has
an add_action method (usually a subclass of Qt::Widget) to make the construction of
collections of actions more rubyish.
Menus are generally made up of a collection of actions.

Once included, it's intended to be called as follows:
  def some_setup_method_or_other
    build_actions do
      list :edit do
        #~ new_action :action_cut, 'Cu&t', :shortcut => Qt::KeySequence::Cut
        action :action_copy, '&Copy', :shortcut => Qt::KeySequence::Copy, :method => :copy_current_selection
        action :action_paste, '&Paste', :shortcut => Qt::KeySequence::Paste, :method => :paste
        separator
        action :action_ditto, '&Ditto', :shortcut => 'Ctrl+\'', :method => :ditto, :tool_tip => 'Copy same field from previous record'
        action :action_ditto_right, 'Ditto R&ight', :shortcut => 'Ctrl+]', :method => :ditto_right, :tool_tip => 'Copy field one to right from previous record'
        action :action_ditto_left, '&Ditto L&eft', :shortcut => 'Ctrl+[', :method => :ditto_left, :tool_tip => 'Copy field one to left from previous record'
        action :action_insert_date, 'Insert Date', :shortcut => 'Ctrl+;', :method => :insert_current_date
        action :action_open_editor, '&Open Editor', :shortcut => 'F4', :method => :open_editor
        separator
        action :action_row, 'New Ro&w', :shortcut => 'Ctrl+N', :method => :row
        action :action_refresh, '&Refresh', :shortcut => 'Ctrl+R', :method => :refresh
        action :action_delete_rows, 'Delete Rows', :shortcut => 'Ctrl+Delete', :method => :delete_rows
        
        if $options[:debug]
          action :action_dump, 'D&ump', :shortcut => 'Ctrl+Shift+D' do
            puts model.collection[current_index.row].inspect
          end
        end
      end
      
      separator
    end
  end
Or you can pass a parameter to the block if you need access to surrounding variables:
  build_actions do |ab|
    ab.list :edit do
      #~ new_action :action_cut, 'Cu&t', :shortcut => Qt::KeySequence::Cut
      ab.action :action_copy, '&Copy', :shortcut => Qt::KeySequence::Copy, :method => :copy_current_selection
    end
  end
If the including class defines a method called action_triggered( &block ),
it can be used to wrap the code triggered by actions. That way, the
including class
can catch exceptions and things like that.
  def action_triggered( &block )
    catch :something_happened do
      yield
    end
  end
If this method is not defined, it will be created in the including class as an empty wrapper.
=end
module ActionBuilder
  # raise a RuntimeError if the including class/module does not define add_action
  def self.included( including_module )
    shortlist = including_module.instance_methods.grep /action/i
    # add_action is actually an method_missing lookup for addAction, so
    # search for both.
    unless shortlist.any? {|x| %w{add_action addAction}.include?( x )}
      raise NotImplementedError, "#{including_module.class.name} must have an add_action method"
    end
  end
  
  # Outer block for the build process.
  def build_actions( &block )
    raise 'a block must be present' if block.nil?
    if block.arity == -1
      instance_eval &block
    else
      yield self
    end
  end
  
  def group_names
    @group_names ||= []
  end
  
  # Create a new separator and add a new separator.
  def separator
    Qt::Action.new( parent ) do |action|
      action.separator = true
      add_action action
      collect_actions << action
    end
  end
  
  # Create and return a list of actions. The actions are grouped together, but not
  # as strongly as with Qt::ActionGroup.
  # A method called "#{group_name}_actions" will be added to self, which will return the
  # set of Qt::Action instances created in the block.
  def list( group_name, &block )
    @group_name = group_name
    group_names << group_name
    unless respond_to?( "#{group_name.to_s}_actions" )
      self.class.send( :define_method, "#{group_name.to_s}_actions" ) do
        eval "@#{group_name.to_s}_actions"
      end
    end
    self.collect_actions = []
    
    yield( self )
    # copy actions to the right instance variable
    eval "@#{group_name.to_s}_actions = collect_actions"
    
    # reset these, just for cleanliness
    @group_name = nil
    self.collect_actions = []
  end
  
  # Create a new Qt::Action and
  # 1. pass it to Qt::Widget::add_action
  # 1. add it to the collect_actions collection.
  # The block takes predence over options[:method], which is a method
  # on self to be called.
  # Option keys can be any method in Qt::Action, ie :tool_tip, :shortcut, :status_tip etc.
  # A value for :shortcut is automatically passed to Qt::KeySequence.new.
  def action( name_or_action, text = nil, options = {}, &block )
    if name_or_action.class == Qt::Action
      add_action( name_or_action )
    else
      name = name_or_action
      if options.has_key?( :method ) && !block.nil?
        raise "you can't specify both :method and a block"
      end
      
      Qt::Action.new( parent ) do |action|
        action.object_name = name.to_s
        action.text = text
        options.each do |k,v|
          next if k == :method
          if k == :shortcut
            action.shortcut = Qt::KeySequence.new( v )
          else
            action.send( "#{k.to_s}=", v )
          end
        end
        
        # add action for Qt
        add_action action
        
        # add actions for list. Yes, it's a side-effect.
        # TODO is there a better way to do this?
        collect_actions << action
        
        action_method_or_block( action, options, &block )
      end
    end
  end

protected

  # the set of actions created so far in a particular list.
  def collect_actions
    @collect_actions ||= []
  end
  
  def collect_actions=( arr )
    @collect_actions = arr
  end
  
  # If parent doesn't define this, add it so that 
  # our action_method_or_block will work.
  unless instance_methods.include?( :action_triggered )
    def action_triggered( &someblock )
      yield
    end
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
