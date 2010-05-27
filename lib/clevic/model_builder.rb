require 'activerecord'
require 'facets/dictionary'

require 'clevic/table_model.rb'
require 'clevic/delegates.rb'
require 'clevic/text_delegate.rb'
require 'clevic/cache_table.rb'
require 'clevic/field.rb'

module Clevic

=begin rdoc

== View definition

Clevic::ModelBuilder defines the DSL used to create a UI definition (which is 
actually a set of Clevic::Field instances), including any related tables, 
restrictions on data entry, formatting and so on. The intention was to make
specifying a UI as painless as possible, with framework overhead only where
you need it.

To that end, there are 2 ways to define UIs:

- an Embedded View as part of the model (ActiveRecord::Base or Sequel::Model) object (which is useful if you 
  want minimal framework overhead). Just show me the data, dammit.

- a Separate View in a separate class (which is useful when you want several 
  diffent views of the same underlying table). I want a neato-nifty UI that does
  (relatively) complex things.

I've tried to consistently refer to an instance of an ActiveRecord::Base or
Sequel::Model subclass as an 'entity'.

==Embedded View
Minimal embedded definition is

  class Position < Sequel::Model
    include Clevic::Record
  end

which will build a fairly sensible default UI from the
entity's metadata. Obviously you can use open classes to do

  class Position < Sequel::Model
    has_many :transactions
    belong_to :account
  end

  class Position
    include Clevic::Record
  end

A full-featured UI for an entity called Entry (part of an accounting database)
could be defined like this:

  class Entry < Sequel::Model
    belongs_to :invoice
    belongs_to :activity
    belongs_to :project
    
    include Clevic::Record
    
    # spans of time more than 8 ours are coloured violet
    # because they're often the result of typos.
    def time_color
      return if self.end.nil? || start.nil?
      'darkviolet' if self.end - start > 8.hours
    end
    
    # tooltip for spans of time > 8 hours
    def time_tooltip
      return if self.end.nil? || start.nil?
      'Time interval greater than 8 hours' if self.end - start > 8.hours
    end
    
    define_ui do
      plain       :date, :sample => '28-Dec-08'
      
      # The project field
      relational  :project do |field|
        field.display = 'project'
        field.conditions = 'active = true'
        field.order = 'lower(project)'
        
        # handle data changed events. In this case,
        # auto-fill-in the invoice field.
        field.notify_data_changed do |entity_view, table_view, model_index|
          if model_index.entity.invoice.nil?
            entity_view.invoice_from_project( table_view, model_index ) do
              # move here next if the invoice was changed
              table_view.override_next_index model_index.choppy( :column => :start )
            end
          end
        end
      end
      
      relational  :invoice, :display => 'invoice_number', :conditions => "status = 'not sent'", :order => 'invoice_number'
      
      # call time_color method for foreground color value
      plain       :start, :foreground => :time_color, :tooltip => :time_tooltip
      
      # another way to call time_color method for foreground color value
      plain       :end, :foreground => lambda{|x| x.time_color}, :tooltip => :time_tooltip
      
      # multiline text
      text        :description, :sample => 'This is a long string designed to hold lots of data and description'
      
      relational :activity do
        display    'activity'
        order      'lower(activity)'
        sample     'Troubleshooting'
        conditions 'active = true'
      end
      
      distinct    :module, :tooltip => 'Module or sub-project'
      plain       :charge, :tooltip => 'Is this time billable?'
      distinct    :person, :default => 'John', :tooltip => 'The person who did the work'
      
      records     :order => 'date, start, id'
    end

    def self.define_actions( view, action_builder )
      action_builder.action :smart_copy, 'Smart Copy', :shortcut => 'Ctrl+"' do
        smart_copy( view )
      end
      
      action_builder.action :invoice_from_project, 'Invoice from Project', :shortcut => 'Ctrl+Shift+I' do
        invoice_from_project( view, view.current_index ) do
          # execute the block if the invoice is changed
          
          # save this before selection model is cleared
          current_index = view.current_index
          view.selection_model.clear
          view.current_index = current_index.choppy( :column => :start )
        end
      end
    end
    
    # do a smart copy from the previous line
    def self.smart_copy( view )
      view.sanity_check_read_only
      view.sanity_check_ditto
      
      # need a reference to current_index here, because selection_model.clear will
      # invalidate view.current_index. And anyway, its shorter and easier to read.
      current_index = view.current_index
      if current_index.row >= 1
        # fetch previous item
        previous_item = view.model.collection[current_index.row - 1]
        
        # copy the relevant fields
        current_index.entity.date = previous_item.date if current_index.entity.date.blank?
        # depends on previous line
        current_index.entity.start = previous_item.end if current_index.entity.date == previous_item.date
        
        # copy rest of fields
        [:project, :invoice, :activity, :module, :charge, :person].each do |attr|
          current_index.entity.send( "#{attr.to_s}=", previous_item.send( attr ) )
        end
        
        # tell view to update
        view.model.data_changed do |change|
          change.top_left = current_index.choppy( :column => 0 )
          change.bottom_right = current_index.choppy( :column => view.model.fields.size - 1 )
        end
        
        # move to the first empty time field
        next_field =
        if current_index.entity.start.blank?
          :start
        else
          :end
        end
        
        # next cursor location
        view.selection_model.clear
        view.current_index = current_index.choppy( :column => next_field )
      end
    end

    # Auto-complete invoice number field from project.
    # &block will be executed if an invoice was assigned
    # If block takes one parameter, pass the new invoice.
    def self.invoice_from_project( table_view, current_index, &block )
      if current_index.entity.project != nil
        # most recent entry, ordered in reverse
        invoice = current_index.entity.project.latest_invoice
        unless invoice.nil?
          # make a reference to the invoice
          current_index.entity.invoice = invoice
          
          # update view from top_left to bottom_right
          table_view.model.data_changed( current_index.choppy( :column => :invoice ) )
          
          unless block.nil?
            if block.arity == 1
              block.call( invoice )
            else
              block.call
            end
          end
        end
      end
    end
    
  end

== Separate View

To define a separate ui class, do something like this:
  class Prospect < Clevic::View
    
    # This is the ActiveRecord::Base or Sequel::Model descendant
    entity_class Position
    
    # This must return a ModelBuilder instance, which is made easier
    # by putting the block in a call to model_builder.
    #
    # With no parameter, the block
    # will be evaluated in the context of a Clevic::ModelBuilder instance,
    # otherwise the parameter will have the Clevic::ModelBuilder instance
    # so you can still access the surrounding scope.
    def define_ui
      model_builder do |mb|
        # use the define_ui block from Position
        mb.exec_ui_block( Position )
        
        # any other ModelBuilder code can go here too
        
        # use a different recordset
        mb.records :conditions => "status in ('prospect','open')", :order => 'date desc,code'
      end
    end
  end
  
And you can even inherit UIs:

  class Extinct < Prospect
    def define_ui
      # reuse all UI definitions from Prospect
      super
      # and again another recordset
      model_builder do |mb|
        mb.records :conditions => "status in ('dead')", :order => 'date desc,code'
      end
    end
  end

Obviously you can use any of the Clevic::ModelBuilder calls described above, and exemplified
in the embedded example, inside of the model_builder block.

== DSL detail

This section describes the syntax of the DSL.

=== Field Types and specifiers

There are only a few field types, with lots of options. All field definitions
start with a field type, have an attribute, and take either a hash of options,
or a block for options. If the block specifies a parameter, an instance of
Clevic::Field will be passed. If the block has no parameter, it will be
evaluated in the context of a Clevic::Field instance. All the options specified
can use DSL-style acessors (no assignment =) or assignment statement.

  plain
is an ordinary editable field. Boolean values are displayed as checkboxes.

  text
is a multiline editable field.

  relational
displays a set of values pulled from a belongs_to (many-to-one) relationship.
In other words all the possible related entities that this one could belong_to. Some
concise representation of the related entities are displayed in a combo box.
:display is mandatory. All options applicable to ActiveRecord::Base#find can also be passed.

  distinct
fetches the set of values already in the field, so you don't have to re-type them.
New values are added in the text field part of the combo box. There is some prefix matching.

  restricted
is a combo box that is not editable in the text field part - the user must select
a value from the :set (an array of strings) supplied. If :set has a hash as its value, the field
will display the hash values, and the hash keys will be stored in the db.

  hide
you won't see this field. Actually, it's only useful after a default_ui, or pulling the
definition from somewhere else. It may go away and be replaced by remove.

=== Attribute

The attribute symbol is required, and is the first parameter after the field type. It must refer
to a method already defined in the entity. In other words any of:
- a db column
- a relationship (belongs_to, has_many, etc)
- a plain method that takes no parameters.

will work. Named scopes might also work, but I haven't tried them yet.

You can do things like this:

  plain :entries, :label => 'First Entry', :display => 'first.date', :format => '%d-%b-%y'
  plain :entries, :label => 'Last Entry', :display => 'last.date', :format => '%d-%b-%y'

Where the attribute fetches a collection of related entities, and :display will cause
exactly one of those values to be passed to :format.

=== Options

Optional specifiers follow the attribute, as hash parameters, or as a block. Many of them will
accept as a value one of:
- String, some kind of value
- Symbol, referring to a method on the entity
- Proc which takes the entity as a parameter

See Clevic::Field properties for available options.

=== Menu Items

You can define view/model specific actions ( an Action is Qt talk for menu items and shortcuts).
These will be added to the Edit menu, show up on context-click in the table
display, and can have optional keyboard shortcuts:

  def define_actions( table_view, action_builder )
    action_builder.action :smart_copy, 'Smart Copy', :shortcut => 'Ctrl+"' do
      # a method in the class containing define_actions
      # view.current_index.entity will return the entity instance.
      smart_copy( view )
    end
    
    action_builder.action :invoice_from_project, 'Invoice from Project', :shortcut => 'Ctrl+Shift+I' do
      # a method in the class containing define_actions
      invoice_from_project( view.current_index, view )
    end
  end
  
=== Notifications

Key presses will be sent here:

  # may also be defined as class methods on an entity class.
  def notify_key_press( table_view, key_press_event, current_model_index )
  end

Fields have a property called notify_data_changed, which is called whenever
the field value changes. There is also an view method:

  def notify_data_changed( table_view, top_left_model_index, bottom_right_model_index )
  end

But note that this will override the delegation to the field notify_data_changed
unless super is called.

=== Tab Order

Using an embedded definition, tab order in the browser is defined by the order in which view definitions
are encountered. Which is really useful if you want to have several view definitions in one file and
just execute clevic on that file.

For more complex situations where your code needs to be separated into
multiple files, as is traditional and useful for most non-trivial projects,
the order can be accessed in Clevic::View.order, and specified by

  Clevic::View.order = [Position, Target, Account]

=end
class ModelBuilder
  
  # Create a definition for entity_view (subclass of Clevic::View).
  # Then execute block using self.instance_eval.
  def initialize( entity_view, &block )
    @entity_view = entity_view
    @auto_new = true
    @read_only = false
    @fields = Dictionary.new
    exec_ui_block( &block )
  end
  
  attr_accessor :entity_view
  attr_accessor :find_options
  
  # execute a block containing method calls understood by Clevic::ModelBuilder
  # arg can be something that responds to define_ui_block,
  # or just the block will be executed. If both are present,
  # values in the block will overwrite values in arg's block.
  def exec_ui_block( arg = nil, &block )
    if !arg.nil? and arg.respond_to?( :define_ui_block )
      exec_ui_block( &arg.define_ui_block )
    end

    unless block.nil?
      if block.arity == -1
        instance_eval( &block )
      else
        block.call( self )
      end
    end
    self
  end
  
  # The collection of Clevic::Field instances where visible == true.
  # the visible may go away.
  def fields
    @fields.reject{|id,field| !field.visible}
  end
  
  # return the index of the named field in the collection of fields.
  def index( field_name_sym )
    retval = nil
    fields.each_with_index{|id,field,i| retval = i if field.attribute == field_name_sym.to_sym }
    retval
  end
  
  # The ORM class
  def entity_class
    @entity_view.entity_class
  end
  
  # set read_only to true
  def read_only!
    @read_only = true
  end
  
  # should this table automatically show a new blank record?
  def auto_new( bool )
    @auto_new = bool
  end
  
  # should this table automatically show a new blank record?
  def auto_new?; @auto_new; end

  # an ordinary field, edited in place with a text box
  def plain( attribute, options = {}, &block )
    read_only_default!( attribute, options )
    @fields[attribute] = Clevic::Field.new( attribute.to_sym, entity_class, options, &block )
  end
  
  # an ordinary field like plain, except that a larger edit area can be used
  def text( attribute, options = {}, &block )
    read_only_default!( attribute, options )
    field = Clevic::Field.new( attribute.to_sym, entity_class, options, &block )
    field.delegate = TextDelegate.new( nil, field )
    @fields[attribute] = field
  end
  
  # Returns a Clevic::Field with a DistinctDelegate, in other words
  # a combo box containing all values for this field from the table.
  def distinct( attribute, options = {}, &block )
    field = Clevic::Field.new( attribute.to_sym, entity_class, options, &block )
    field.delegate = DistinctDelegate.new( nil, field )
    @fields[attribute] = field
  end
  
  # a combo box with a set of supplied values
  def combo( attribute, options = {}, &block )
    field = Clevic::Field.new( attribute.to_sym, entity_class, options, &block )
    
    # TODO this really belongs in a separate 'map' field?
    # or maybe put it in SetDelegate?
    if field.set.is_a? Hash
      field.format ||= lambda{|x| field.set[x]}
    end
    
    field.delegate = SetDelegate.new( nil, field )
    @fields[attribute] = field
  end

  # Returns a Clevic::Field with a restricted SetDelegate, 
  def restricted( attribute, options = {}, &block )
    options[:restricted] = true
    combo( attribute, options, &block )
  end

  # for foreign keys. Edited with a combo box using values from the specified
  # path on the foreign key model object
  # if options[:format] has a value, it's used either as a block
  # or as a dotted path
  def relational( attribute, options = {}, &block )
    field = Clevic::Field.new( attribute.to_sym, entity_class, options, &block )
    if field.class_name.nil?
      field.class_name = entity_class.reflections[attribute].class_name || attribute.to_s.classify
    end
    
    # check after all possible options have been collected
    raise ":display must be specified" if field.display.nil?
    field.delegate = RelationalDelegate.new( nil, field )
    @fields[attribute] = field
  end

  # mostly used in the new block to define the set of records
  # for the TableModel, but may also be
  # used as an accessor for records.
  def records( args = {} )
    if args.size == 0
      get_records
    else
      set_records( args )
    end
  end

  # Tell this field not to show up in the UI.
  # Mainly intended to be called after default_ui has been called.
  def hide( attribute )
    field( attribute ).visible = false
  end

  # Build a default UI. All fields except the primary key are displayed
  # as editable in the table. Any belongs_to relations are used to build
  # combo boxes. Default ordering is the primary key.
  # Subscriber is already defined elsewhere as a subclass
  # of an ORM class, ie ActiveRecord::Base, Sequel::Model:
  #   class Subscriber
  #     include Clevic::Record
  #     define_ui do
  #       default_ui
  #       plain :password # this field does not exist in the DB
  #       hide :password_salt # these should be hidden
  #       hide :password_hash
  #     end
  #   end
  #
  # An attempt to use a sensible :display option for the related class. In order:
  # * the name of the class
  # * :name
  # * :title
  # * :username
  def default_ui
    # combine reflections and attributes into one set
    reflections = entity_class.reflections.keys.map{|x| x.to_s}
    ui_columns = entity_class.columns.reject{|x| x.name == entity_class.primary_key }.map do |column|
      # TODO use entity_class.meta and ModelColumn
      att = column.name.gsub( /_id$/, '' )
      if reflections.include?( att )
        att
      else
        column.name
      end
    end
    
    # don't create an empty record, because sometimes there are
    # validations that will cause trouble
    auto_new false
    
    # build columns
    # TODO use ModelColumn for this
    ui_columns.each do |column|
      if entity_class.reflections.has_key?( column.to_sym )
        begin
          reflection = entity_class.reflections[column.to_sym]
          if reflection.class == ActiveRecord::Reflection::AssociationReflection
            related_class = reflection.class_name.constantize
            
            # try to find a sensible display class. Default to to_s
            display_method =
            %w{#{entity_class.name} name title username}.find( lambda{ 'to_s' } ) do |m|
              related_class.column_names.include?( m ) || related_class.instance_methods.include?( m )
            end
            
            # set the display method
            relational column.to_sym, :display => display_method
          else
            plain column.to_sym
          end
        rescue
          puts $!.message
          puts $!.backtrace
          # just do a plain
          puts "Doing plain for #{entity_class}.#{column}"
          plain column.to_sym
        end
      else
        plain column.to_sym
      end
    end
    records :order => entity_class.primary_key
  end
  
  # return the named Clevic::Field object
  def field( attribute )
    @fields.find {|id,field| field.attribute == attribute }
  end
  
  # This takes all the information collected
  # by the other methods, and returns a new TableModel
  # with the given table_view as its parent.
  def build( table_view )
    # build the model with all it's collections
    # using @model here because otherwise the view's
    # reference to this very same model is garbage collected.
    @model = Clevic::TableModel.new( table_view )
    @model.builder = self
    @model.entity_view = entity_view
    @model.fields = @fields.values
    @model.read_only = @read_only
    @model.auto_new = auto_new?
    
    # setup model
    table_view.object_name = @object_name
    # set parent for all delegates
    fields.each {|id,field| field.delegate.parent = table_view unless field.delegate.nil? }
    
    # the data
    @model.collection = records
    
    @model
  end
  
protected

  # set a sensible read-only value if it isn't already specified in options
  def read_only_default!( attribute, options )
    # sensible defaults for read-only-ness
    options[:read_only] ||= 
    case
      when options[:display].respond_to?( :call )
        # it's a Proc or a Method, so we can't set it
        true
        
      when entity_class.column_names.include?( options[:display].to_s )
        # it's a DB column, so it's not read only
        false
        
      when entity_class.reflections.include?( attribute )
        # one-to-one relationships can be edited. many-to-one certainly can't
        entity_class.meta( attribute ).type != :many_to_one
        
      when entity_class.instance_methods.include?( attribute.to_s )
        # read-only if there's no setter for the attribute
        !entity_class.instance_methods.include?( "#{attribute.to_s}=" )
      else
        # default to not read-only
        false
    end
  end

  # The collection of model objects to display in a table
  # arg can either be a Hash, in which case a new CacheTable
  # is created, or it can be an array.
  # Called by records( *args )
  def set_records( arg )
    if arg.class == Hash
      # need to defer this until all fields are collected
      @find_options = arg
    else
      @records = arg
    end
  end

  # Return a collection of records. Usually this will be a CacheTable.
  # Called by records( *args )
  def get_records
    if @records.nil?
      @records = CacheTable.new( entity_class, @find_options )
    end
    @records
  end
  
end

end
