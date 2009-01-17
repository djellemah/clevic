require 'activerecord'

require 'clevic/table_model.rb'
require 'clevic/delegates.rb'
require 'clevic/cache_table.rb'
require 'clevic/field.rb'

module Clevic

=begin rdoc
This is used to define a set of Clevic::Field objects in a UI which
includes any related tables,
restrictions on data entry, formatting and so on. Then the build method
uses the set of fields to construct a Clevic::TableModel.

The type of the field (plain, relational, distinct, restricted, hide) defines
must be followed by the attribute on the current entity (an ActiveRecord or descendant).

Optional specifiers are:
* :format is something that can be understood by strftime (for time and date
  fields) or understood by % (for everything else). It can also be a Proc
  that has one parameter - the current entity. There are sensible defaults for common field
  types.
* :alignment is one of :left, :right, :justified, :centre. Default is :right for numeric,
  and :left for text and most other things.
* :label is the text to be displayed in colum headings
* :display is the value to be displayed, in other words either a dotted accessor path, or a Proc with the current entity as its argument.
* :read_only is a boolean. Pretty self-explanatory.
* :edit_format is the format to be used to transform the value for editing. For
  example, a date that displays a 2-digit year must be edited with a 4-digit year.
  Defaults to the value of :format.
* :sample is a string used to size the columns. Default is the longest value in this field from the
  table, provided it isn't too long.

restricted fields also require:
* :set which is the set of strings that are accepted by a RestrictedDelegate

For relational fields, all other options are passed to ActiveRecord::Base#find,
and apply to the set of values displayed in the combo box.

For example, the UI for a model called Entry (part of an accounting database) could be defined like this:

  # inherit from Clevic::Record, which itself inherits from ActiveRecord::Base
  class Entry < Clevic::Record
    # ActiveRecord foreign key definition
    belongs_to :debit, :class_name => 'Account', :foreign_key => 'debit_id'
    # ActiveRecord foreign key definition
    belongs_to :credit, :class_name => 'Account', :foreign_key => 'credit_id'

    define_ui do
      # :format and :edit_format are optional, in fact these are the defaults
      plain       :date, :format => '%d-%h-%y', :edit_format => '%d-%h-%Y'
      plain       :start, :format => '%H:%M'
      plain       :amount, :format => '%.2f'
      # :set is mandatory for a restricted field
      restricted  :vat, :label => 'VAT', :set => %w{ yes no all }, :tooltip => 'Is VAT included?'
      
      # alternately with a block for readability
      restricted :vat do
        label   'VAT'
        set     %w{ yes no all }
        tooltip 'Is VAT included?'
      end
      
      # distinct will retrieve from the table all other values for this field
      # and display them in the combo.
      distinct    :description, :conditions => 'now() - date <= interval( 1 year )'

      # this is a read-only field
      plain       :origin, :read_only => true
      
      # :format is an attribute on the related
      # ActiveRecord entity, in this case an instance of Account
      # :order is an ActiveRecord option to find, defining the order in which related entries will be displayed.
      # :conditions is an ActiveRecord option to find, defining the subset of related entries to be displayed.
      relational  :debit, :format => 'name', :conditions => 'active = true', :order => 'lower(name)'
      relational  :credit, :format => 'name', :conditions => 'active = true', :order => 'lower(name)'
      
      # or like this to have an on-the-fly transform. item will be an instance of Account
      relational :credit do
        :format => lambda {|item| item.name.downcase}
        :conditions => 'active = true'
        :order => 'lower(name)'
      end
      
      # this is a read-only display field from a related table
      # the Entry class should then define a method called currency
      # which returns an object that responds to 'short'.
      # You can also use a Proc for :display
      plain :currency, :display => 'short', :label => 'Currency'
      
      # this is a read-only display field from a related table
      # the Entry class should then define a method called currency
      # which returns an object that responds to 'currency', which
      # returns an object that responds to 'rate'.
      # You can also use a Proc for :display
      plain :some_field, :display => 'currency.rate', :label => 'Exchange Rate'
      
      # this is optional. By default all records in id order will be displayed.
      records :order => 'date,start'
      
      # could also be like this, where a..e are instances of Entry
      records [ a,b,c,d,e ]
    end
  end
  
For ActiveRecord::Base classes, ModelBuilder has a default_ui method
which knows how to build a
fairly sensible default UI.

Subclasses of Clevic::Record may also implement
* <tt>self.key_press_event( event, current_index, table_view )</tt>
* <tt>self.data_changed( top_left_index, bottom_right_index, table_view )</tt>
so that they can respond to editing events and do Neat Stuff.
=end
class ModelBuilder
  
  # Create a definition for entity_class (subclass of ActiveRecord::Base
  # or Clevic::Record). Then execute block using self.instance_eval.
  # The builder will construct a default TableModel from the entity_class
  # unless can_build_default == false
  def initialize( entity_class, can_build_default = true, &block )
    @entity_class = entity_class
    @auto_new = true
    @read_only = false
    @fields = []
    init_from_model( entity_class, can_build_default, &block )
  end
  
  # The collection of visible Clevic::Field objects
  def fields
    @fields.reject{|x| !x.visible}
  end
  
  # return the index of the named field in the collection of fields.
  def index( field_name_sym )
    retval = nil
    fields.each_with_index{|x,i| retval = i if x.attribute == field_name_sym.to_sym }
    retval
  end
  
  # the ActiveRecord::Base or Clevic::Record class
  attr_reader :entity_class
  
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
    # get values from block, if it's there
    options = HashCollector.new( options, &block ).to_hash
    
    read_only_default!( attribute, options )
    @fields << Clevic::Field.new( attribute.to_sym, entity_class, options )
  end
  
  # Returns a Clevic::Field with a DistinctDelegate, in other words
  # a combo box containing all values for this field from the table.
  def distinct( attribute, options = {}, &block )
    # get values from block, if it's there
    options = HashCollector.new( options, &block ).to_hash
    
    field = Clevic::Field.new( attribute.to_sym, entity_class, options )
    field.delegate = DistinctDelegate.new( nil, attribute, entity_class, options )
    @fields << field
  end

  # Returns a Clevic::Field with a RestrictedDelegate, 
  # a combo box, but restricted to a specified set, from the :set option.
  def restricted( attribute, options = {}, &block )
    # get values from block, if it's there
    options = HashCollector.new( options, &block ).to_hash
    
    raise "restricted must have a set" unless options.has_key?( :set )
    
    if options[:set].is_a? Hash
      options[:format] = lambda{|x| options[:set][x]}
    end
    field = Clevic::Field.new( attribute.to_sym, entity_class, options )
    field.delegate = RestrictedDelegate.new( nil, attribute, entity_class, options )
    @fields << field
  end

  # for foreign keys. Edited with a combo box using values from the specified
  # path on the foreign key model object
  # if options[:format] has a value, it's used either as a block
  # or as a dotted path
  def relational( attribute, options = {}, &block )
    unless options.has_key? :class_name
      options[:class_name] = entity_class.reflections[attribute].class_name || attribute.to_s.classify
    end
    
    # get values from block, if it's there
    options = HashCollector.new( options, &block ).to_hash
    
    # check after all possible options have been collected
    raise ":display must be specified" if options[:display].nil?
    
    field = Clevic::Field.new( attribute.to_sym, entity_class, options )
    field.delegate = RelationalDelegate.new( nil, field.attribute_path, options )
    @fields << field
  end

  # mostly used in the new block to define the set of records
  # for the TableModel, but may also be
  # used as an accessor for records.
  def records( *args )
    if args.size == 0
      get_records
    else
      set_records( args[0] )
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
  # For small tweaks (large changes belong in a proper define_ui block),
  # something like this
  # can be used (where Subscriber is already defined elsewhere as a subclass
  # of ActiveRecord::Base):
  #   class Subscriber
  #     post_default_ui do
  #       plain :password # this field does not exist in the DB
  #       hide :password_salt # these should be hidden
  #       hide :password_hash
  #     end
  #   end
  # This method will try to use a sensible :display option for the related class. In order:
  # * the name of the class
  # * :name
  # * :title
  # * :username
  def default_ui
    # combine reflections and attributes into one set
    reflections = entity_class.reflections.keys.map{|x| x.to_s}
    ui_columns = entity_class.columns.reject{|x| x.name == entity_class.primary_key }.map do |column|
      # TODO there must be a better way to do this
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
    @fields.find {|x| x.attribute == attribute }
  end
  
  # This takes all the information collected
  # by the other methods, and returns the new TableModel
  def build( table_view )
    # build the model with all it's collections
    # using @model here because otherwise the view's
    # reference to this very same model is garbage collected.
    @model = Clevic::TableModel.new( table_view )
    @model.object_name = entity_class.name
    @model.entity_class = entity_class
    @model.fields = @fields
    @model.read_only = @read_only
    @model.auto_new = auto_new?
    
    # set parent for all delegates
    fields.each {|x| x.delegate.parent = table_view unless x.delegate.nil? }
    
    # the data
    @model.collection = records
    
    @model
  end
  
protected

  def init_from_model( entity_class, can_build_default, &block )
    if entity_class.respond_to?( :build_table_model )
      # call build_table_model
      method = entity_class.method :build_table_model
      method.call( builder )
    elsif !entity_class.define_ui_block.nil?
      #define_ui is used, so use that block
      instance_eval( &entity_class.define_ui_block )
    elsif can_build_default
      # build a default UI
      default_ui
      
      # allow for smallish changes to a default build
      instance_eval( &entity_class.post_default_ui_block ) unless entity_class.post_default_ui_block.nil?
    end

    # the local block adds to the previous definitions
    unless block.nil?
      if block.arity == 0
        instance_eval( &block )
      else
        yield( builder )
      end
    end
  end
  
  # Add ActiveRecord :include options for foreign keys, but it takes up too much memory,
  # and actually takes longer to load a data set.
  #--
  # TODO ActiveRecord-2.1 has smarter includes
  def add_include_options
    fields.each do |field|
      if field.delegate.class == RelationalDelegate
        @options[:include] ||= []
        @options[:include] << field.attribute
      end
    end
  end

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
        reflection = entity_class.reflections[attribute]
        reflection.macro != :has_one
        
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
      @options = arg
    else
      @records = arg
    end
  end

  # Return a collection of records. Usually this will be a CacheTable.
  # Called by records( *args )
  def get_records
    if @records.nil?
      #~ add_include_options
      @options[:auto_new] = auto_new?
      @records = CacheTable.new( entity_class, @options )
    end
    @records
  end
  
end

end
