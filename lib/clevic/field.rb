require 'gather.rb'
require 'clevic/sampler.rb'
require 'clevic/generic_format.rb'

module Sequel
  class Model
    class Errors
      def invalid?( field_name )
        self.has_key?( field_name )
      end
    end
  end
end

module Clevic

=begin rdoc
This defines a field in the UI, and how it hooks up to a field in the DB.

Many attributes are DSL-style accessors, where the value can be
set with either an assignment or by passing a parameter. Unfortunately
rdoc seems to have lost the ability to display these nicely. Anyway, here's
an example

  property :ixnay

will allow

  # reader
  instance.ixnay
  
  # writer
  instance.ixnay = 'nix, baby'
  
  # writer
  instance.ixnay 'nix baby'

  # store the block for later
  instance.ixnay do |*args|
    # block stuff here
  end

Generally properties are for options that can be passed to the field creation
method in ModelBuilder, whereas ruby attributes are for the internal workings.

#--
TODO decide whether value_for type methods take an entity and do_something methods
take a value.

TODO this class is a bit confused about whether it handles metadata or record data, or both.

TODO meta needs to handle virtual fields better.
=end
class Field
  # For defining properties
  include Gather
  
  # for formatting values
  include GenericFormat
  
  ##
  # The value to be displayed after being optionally format-ed
  #
  # Takes a String, a Symbol, or a Proc.
  #
  # A String will be a dot-separated path of attributes starting on the object returned by attribute.
  # Paths longer than 1 element haven't been tested much.
  #
  # A Symbol refers to a method to be called on the current entity
  #
  # A Proc will be passed the current entity. This can be used to display 'virtual'
  # fields from related tables, or calculated fields.
  #
  # Defaults to nil, in other words the value of the attribute for this field.
  property :display
  
  ##
  # The label to be displayed in the column headings. Defaults to the humanised field name.
  property :label
  
  ##
  # For relational fields, this is the class_name for the related AR entity.
  # TODO not used anymore?
  property :class_name
  
  ##
  # One of the alignment specifiers - :left, :centre, :right or :justified.
  # Defaults to right for numeric fields, centre for boolean, and left for
  # other values.
  property :alignment
  
  ##
  # something to do with the icon that Qt displays. Not implemented yet.
  property :decoration
  
  ##
  # This defines how to format the value returned by :display. It takes a string or a Proc.
  # Generally the string is something 
  # that can be understood by strftime (for time and date fields) or understood 
  # by % (for everything else). It can also be a Proc that has one parameter - 
  # the current entity. There are sensible defaults for common field types.
  property :format
  
  ##
  # This is just like format, except that it's used to format the value just
  # before it's edited. A good use of this is to display dates with a 2-digit year
  # but edit them with a 4 digit year.
  # Defaults to a sensible value for some fields, for others it will default to the value of :format.
  property :edit_format
  
  ##
  # Whether the field is currently visible or not.
  property :visible
  
  ##
  # Sample is used if the programmer wishes to provide a value (that will be converted
  # using to_s) that can be used
  # as the basis for calculating the width of the field. By default this will be
  # calculated from the database, but this may be an expensive operation, and
  # doesn't always work properly. So we
  # have the option to override that if we wish.
  property :sample
  
  ##
  # Takes a boolean. Set the field to read-only.
  property :read_only
  
  ##
  # The foreground and background colors.
  # Can take a Proc, a string, or a symbol.
  # - A Proc is called with an entity
  # - A String is treated as a constant which may be one of the string constants understood by Qt::Color
  # - A symbol is treated as a method to be call on an entity
  #
  # The result can be a Qt::Color, or one of the strings in 
  # http://www.w3.org/TR/SVG/types.html#ColorKeywords.
  property :foreground, :background
  
  ##
  # Can take a Proc, a string, or a symbol.
  # - A Proc is called with an entity
  # - A String is treated as a constant
  # - A symbol is treated as a method to be call on an entity
  property :tooltip
  
  ##
  # An Enumerable of allowed values for restricted fields. If each yields
  # two values (like it does for a Hash), the
  # first will be stored in the db, and the second displayed in the UI.
  # If it's a proc, it must return an Enumerable as above.
  property :set
  
  ##
  # When this is true, only the values in the combo may be entered.
  # Otherwise the text-entry part of the combo can be used to enter
  # non-listed values. Default is true if a set is explicitly specified.
  # Otherwise depends on the field type.
  property :restricted
  
  ##
  # Only for the distinct field type. The values will be sorted either with the
  # most used values first (:frequency => true) or in
  # alphabetical order (:description => true).
  property :frequency, :description
  
  ##
  # Default value for this field for new records.
  # Can be a Proc or a value. A value will just be
  # set, a proc will be executed with the entity as a parameter.
  property :default
  
  ##
  # The property used for finding the field, ie by TableModel#field_column.
  # Defaults to the attribute.
  property :id
  
  ##
  # Called when the data in this field changes.
  # Either a proc( clevic_view, table_view, model_index ) or a symbol
  # for a method( view, model_index ) on the Clevic::View object.
  property :notify_data_changed
  
  # The list of properties for ActiveRecord options.
  # There are actually from ActiveRecord::Base.VALID_FIND_OPTIONS, but it's protected.
  # Each element becomes a property.
  AR_FIND_OPTIONS = [ :conditions, :include, :joins, :limit, :offset, :order, :select, :readonly, :group, :from, :lock ]
  AR_FIND_OPTIONS.each{|x| property x}
  
  # Return a list of find options and their values, but only
  # if the values are not nil
  def find_options
    AR_FIND_OPTIONS.inject(Hash.new) do |ha,x|
      option_value = self.send(x)
      unless option_value.nil?
        ha[x] = option_value
      end
      ha
    end
  end
  
  # The UI delegate class for the field. In Qt, this is a subclass of AbstractItemDelegate.
  attr_accessor :delegate
  
  # The attribute on the AR entity that forms the basis for this field.
  # Accessing the returned attribute (using send, or the [] method on an entity)
  # will give a simple value, or another AR entity in the case of relational fields.
  # In other words, this is *not* the same as the name of the field in the DB, which
  # would normally have an _id suffix for relationships.
  attr_accessor :attribute
  
  # The ActiveRecord::Base subclass this field uses to get data from.
  attr_reader :entity_class
  
  # Create a new Field object that displays the contents of a database field in
  # the UI using the given parameters.
  # - attribute is the symbol for the attribute on the entity_class.
  # - entity_class is the ActiveRecord::Base subclass which this Field talks to.
  # - options is a hash of writable attributes in Field, which can be any of the properties defined in this class.
  def initialize( attribute, entity_class, options, &block )
    # sanity checking
    unless attribute.is_a?( Symbol )
      raise "attribute #{attribute.inspect} must be a symbol"
    end
    
    # TODO AR dependent
    unless entity_class.has_attribute?( attribute ) or entity_class.instance_methods.include?( attribute.to_s )
      msg = <<EOF
#{attribute} not found in #{entity_class.name}. Possibilities are:
#{entity_class.attribute_names.join("\n")}
EOF
      raise msg
    end
    
    # instance variables
    @attribute = attribute
    # default to attribute
    @id = attribute
    @entity_class = entity_class
    @visible = true
    
    # initialise
    @value_cache = {}
    
    # handle options
    gather( options, &block )
    
    # set various sensible defaults. They're not lazy accessors because
    # they might stay nil, and we don't want to keep evaluating them.
    default_label!
    default_format!
    default_edit_format!
    default_alignment!
  end
  
  # Return the attribute value for the given ActiveRecord entity, or nil
  # if entity is nil. Will call transform_attribute.
  def value_for( entity )
    begin
      return nil if entity.nil?
      transform_attribute( entity.send( attribute ) )
    rescue Exception => e
      puts "error for #{entity}.#{entity.send( attribute ).inspect} in value_for: #{e.message}"
      puts e.backtrace
    end
  end
  
  # Apply the value of the display property to the given
  # attribute value. Otherwise just return the
  # attribute_value itself.
  def transform_attribute( attribute_value )
    return nil if attribute_value.nil?
    case display
      when Proc
        display.call( attribute_value )
        
      when String
        attribute_value.evaluate_path( display.split( '.' ) )
      
      when Symbol
        attribute_value.send( display )
      
      else
        attribute_value
    end
  end
  
  # return true if this is a field for a related table, false otherwise.
  def is_association?
    meta.type == ActiveRecord::Reflection::AssociationReflection
  end
  
  # ModelColumn object
  def meta
    entity_class.meta[attribute]
  end
  
  # return the type of this attribute. Usually one of :string, :integer, :float
  # or some entity class (ActiveRecord::Base subclass)
  def attribute_type
    @attribute_type ||=
    if meta.kind_of?( ActiveRecord::Reflection::MacroReflection )
      meta.klass
    else
      meta.type
    end
  end

  # return true if this field can be used in a filter
  # virtual fields (ie those that don't exist in this field's
  # table) can't be used to filter on.
  def filterable?
    !meta.nil?
  end
  
  # return the result of the attribute + the path
  def column
    [attribute.to_s, path].compact.join('.')
  end
  
  # return an array of the various attribute parts
  def attribute_path
    pieces = [ attribute.to_s ]
    pieces.concat( display.to_s.split( '.' ) ) unless display.is_a? Proc
    pieces.map{|x| x.to_sym}
  end
  
  # Return true if the field is read-only. Defaults to false.
  def read_only?
    @read_only || false
  end
  
  # Called by Clevic::Model to format the display value.
  def do_format( value )
    do_generic_format( format, value )
  end
  
  # Called by Clevic::Model to format the edit value.
  def do_edit_format( value )
    do_generic_format( edit_format, value )
  end
  
  # Return a sample for the field which can be used to size the UI field widget.
  def sample( *args )
    if !args.empty?
      @sample = *args
      return self
    end
    
    @sample ||= Sampler.new( entity_class, attribute, display ) do |value|
      do_format( value )
    end.compute
    
    # if we don't know how to figure it out from the data, just return the label size
    @sample || self.label
  end
  
  # Called by Clevic::TableModel to get the tooltip value
  def tooltip_for( entity )
    cache_value_for( :tooltip, entity )
  end

  # TODO Doesn't do anything useful yet.
  def decoration_for( entity )
    nil
  end

  # Convert something that responds to to_s into a Qt::Color,
  # or just return the argument if it's already a Qt::Color
  def string_or_color( s_or_c )
    case s_or_c
    when NilClass
      nil
    when Qt::Color
      s_or_c
    else
      Qt::Color.new( s_or_c.to_s )
    end
  end
  
  # Called by Clevic::TableModel to get the foreground color value
  def foreground_for( entity )
    cache_value_for( :foreground, entity ) {|x| string_or_color(x)}
  end
  
  # Called by Clevic::TableModel to get the background color value
  def background_for( entity )
    cache_value_for( :background, entity ) {|x| string_or_color(x)}
  end
  
  # called when a new entity object is created to set default values
  # specified by the default property.
  def set_default_for( entity )
    begin
      entity[attribute] = 
      case default
        when String
          default
        when Proc
          default.call( entity )
      end
    rescue Exception => e
      puts e.message
      puts e.backtrace
    end
  end
  
  # fetch the permitted set of values for a restricted field.
  def set_for( entity )
    case set
      when Proc
        # the Proc should return an enumerable
        set.call( entity )
        
      when Symbol
        entity.send( set )
        
      else
        # assume its an Enumerable
        set
    end
  end
  
protected

  # call the conversion_block with the value, or just return the
  # value if conversion_block is nil
  def convert_or_identity( value, &conversion_block )
    if conversion_block.nil?
      value
    else
      conversion_block.call( value )
    end
  end
  
  # symbol is the property name to fetch a value for.
  # It can be a Proc, a symbol, or a value responding to to_s.
  # In all cases, conversion block will be called
  # conversion_block takes the value expected back from the property
  # and converts it to something that Qt will understand. Mostly
  # this applies to non-strings, ie colors for foreground and background,
  # and an icon resource for decoration - that kind of thing.
  def cache_value_for( symbol, entity, &conversion_block )
    value = send( symbol )
    case value
      when Proc; convert_or_identity( value.call( entity ), &conversion_block ) unless entity.nil?
      when Symbol; convert_or_identity( entity.send( value ), &conversion_block ) unless entity.nil?
      else; @value_cache[symbol] ||=convert_or_identity( value, &conversion_block )
    end
  end
  
  # the label if it's not defined. Based on the attribute.
  def default_label!
    @label ||= attribute.to_s.humanize
  end

  # sensible display format defaults if they're not defined.
  def default_format!
    if @format.nil?
      @format =
      case meta.type
        when :time; '%H:%M'
        when :date; '%d-%h-%y'
        when :datetime; '%d-%h-%y %H:%M:%S'
        when :decimal, :float; "%.2f"
      end
    end
    @format
  end
  
  # sensible edit format defaults if they're not defined.
  def default_edit_format!
    if @edit_format.nil?
      @edit_format =
      case meta.type
        when :date; '%d-%h-%Y'
        when :datetime; '%d-%h-%Y %H:%M:%S'
      end || default_format!
    end
    @edit_format
  end

  # sensible alignment defaults if they're not defined.
  def default_alignment!
    if @alignment.nil?
      @alignment =
      case meta.type
        when :decimal, :integer, :float; :right
        when :boolean; :centre
      end
    end
  end

end

end
