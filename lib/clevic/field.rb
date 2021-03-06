require 'gather'
require 'clevic/sampler.rb'
require 'clevic/generic_format.rb'
require 'clevic/dataset_roller.rb'
require 'clevic/many_field.rb'

module Clevic

=begin rdoc

This defines a field in the UI, and how it hooks up to a field in the DB.

Some attributes are DSL-style accessors, where the value can be
set with either an assignment or by passing a parameter. For example:

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
Yes, the blank line before class Field is really necessary.
And so it the #-- above.
=end

class Field
  # For defining properties
  include Gather

  # for formatting values
  include GenericFormat

  ##
  # :attr:
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
  # :attr:
  # The label to be displayed in the column headings. Defaults to the humanised field name.
  property :label

  ##
  # :attr:
  # One of the alignment specifiers - :left, :centre, :right or :justified.
  # Defaults to right for numeric fields, centre for boolean, and left for
  # other values.
  property :alignment

  ##
  # :attr:
  # something to do with the icon that Qt displays. Not implemented yet.
  property :decoration

  ##
  # :attr:
  # This defines how to format the value returned by :display. It takes a string or a Proc.
  # Generally the string is something
  # that can be understood by strftime (for time and date fields) or understood
  # by % (for everything else). It can also be a Proc that has one parameter -
  # the current entity. There are sensible defaults for common field types.
  property :format

  ##
  # :attr:
  # This is just like format, except that it's used to format the value just
  # before it's edited. A good use of this is to display dates with a 2-digit year
  # but edit them with a 4 digit year.
  # Defaults to a sensible value for some fields, for others it will default to the value of :format.
  property :edit_format

  ##
  # :attr:
  # Whether the field is currently visible or not.
  property :visible

  ##
  # :attr:
  # Sample is used if the programmer wishes to provide a value (that will be converted
  # using to_s) that can be used
  # as the basis for calculating the width of the field. By default this will be
  # calculated from the database, but this may be an expensive operation, and
  # doesn't always work properly. So we
  # have the option to override that if we wish.
  property :sample

  ##
  # :attr:
  # Takes a boolean. Set the field to read-only.
  property :read_only

  ##
  # :attr:
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
  # :attr:
  # Can take a Proc, a string, or a symbol.
  # - A Proc is called with an entity
  # - A String is treated as a constant
  # - A symbol is treated as a method to be call on an entity
  property :tooltip

  ##
  # :attr:
  # An Enumerable of allowed values for restricted fields. If each yields
  # two values (like it does for a Hash), the
  # first will be stored in the db, and the second displayed in the UI.
  # If it's a proc, that must return an Enumerable as above.
  property :set

  ##
  # :attr:
  # When this is true, only the values in the combo may be entered.
  # Otherwise the text-entry part of the combo can be used to enter
  # non-listed values. Default is true if a set is explicitly specified.
  # Otherwise depends on the field type.
  property :restricted

  ##
  # :attr:
  # Only for the distinct field type. The values will be sorted either with the
  # most used values first (:frequency => true) or in
  # alphabetical order (:description => true).
  # FIXME re-implement this with Dataset
  property :frequency, :description

  ##
  # :attr:
  # Default value for this field for new records.
  # Can be a Proc or a value. A value will just be
  # set, a proc will be executed with the entity as a parameter.
  property :default

  ##
  # :attr:
  # The property used for finding the field, ie by TableModel#field_column.
  # Defaults to the attribute. If there are several display fields based on
  # one db field, their attribute will be the same, but their id must be different.
  property :id

  ##
  # :attr:
  # Called when the data in this field changes.
  # Either a proc( clevic_view, table_view, model_index ) or a symbol
  # for a method( view, model_index ) on the Clevic::View object.
  property :notify_data_changed

  ##
  # This is the dataset of related objects.
  # Called in configuration for a field that works with a relationship.
  #  dataset.filter( :blah => 'etc' ).order( :interesting_field )
  def dataset
    dataset_roller
  end

  # TODO Still getting the Builder/Built conflict
  def dataset_roller
    # related class if it's an association, entity_class otherwise
    @dataset_roller ||= DatasetRoller.new( ( association? ? related_class : entity_class ).dataset )
  end

  # The list of properties for ActiveRecord options.
  # There are actually from ActiveRecord::Base.VALID_FIND_OPTIONS, but it's protected.
  # Each element becomes a property.
  # TODO deprecate these
  # TODO warn or raise if these are used together with a dataset call
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

  # The model object (eg TableModel) this field is part of.
  # Set to TableModel by ModelBuilder#build
  attr_accessor :model

  # The UI delegate class for the field. The delegate class knows how to create a UI
  # for this field using whatever GUI toolkit is selected
  attr_accessor :delegate

  # The attribute on the entity that forms the basis for this field.
  # Accessing the returned attribute (using send, or the [] method on an entity)
  # will give a simple value, or another entity in the case of relational fields.
  # In other words, this is *not* the same as the name of the field in the DB, which
  # would normally have an _id suffix for relationships.
  attr_accessor :attribute

  # The Object Relational Model this field uses to get data from.
  attr_reader :entity_class

  # Create a new Field object that displays the contents of a database field in
  # the UI using the given parameters.
  # - attribute is the symbol for the attribute on the entity_class.
  # - entity_class is the Object Relational Model which this Field talks to.
  # - options is a hash of writable attributes in Field, which can be any of the properties defined in this class.
  def initialize( attribute, entity_class, options, &block )
    # sanity checking
    unless attribute.is_a?( Symbol )
      raise "attribute #{attribute.inspect} must be a symbol"
    end

    unless entity_class.ancestors.include?( Clevic.base_entity_class )
      raise "#{entity_class} is not a Clevic.base_entity_class: #{Clevic.base_entity_class}"
    end

    # TODO this comes down to method_defined, really
    unless entity_class.has_attribute?( attribute ) or entity_class.method_defined?( attribute )
      raise <<EOF
#{attribute.inspect} not found in #{entity_class.name}. Possibilities are:
#{entity_class.attribute_names.inspect}
EOF
    end

    # instance variables
    @attribute = attribute
    # default to attribute, can be overwritten later
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
    default_display! if association?
  end

  # Return the attribute value for the given Object Relational Model instance, or nil
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
  def association?
    meta.andand.association?
  end

  # Clevic::ModelColumn object
  def meta
    entity_class.meta[attribute] || ModelColumn.new( attribute, {} )
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

  # Return the class object of a related class if this is a relational
  # field, otherwise nil.
  def related_class
    return nil unless association? && entity_class.meta.has_key?( attribute )
    @related_class ||= eval( entity_class.meta[attribute].class_name || attribute.to_s.classify )
  end

  # return an array of the various attribute parts
  # TODO not used much. Deprecate and remove.
  def attribute_path
    pieces = [ attribute.to_s ]
    pieces.concat( display.to_s.split( '.' ) ) unless display.is_a? Proc
    pieces.map{|x| x.to_sym}
  end

  # Return true if the field is read-only. Defaults to false.
  def read_only?
    @read_only || false
  end

  # Called by Clevic::FieldValuer (and others) to format the display value.
  def do_format( value )
    do_generic_format( format, value )
  end

  # Called by Clevic::FieldValuer to format the field to a string value
  # that can be used for editing.
  def do_edit_format( value )
    do_generic_format( edit_format, value )
  end

  # Set or return a sample for the field which can be used to size the UI field widget.
  # If this is called as an accessor, and there is no value yet, a Clevic::Sampler
  # instance is created to compute a sample.
  def sample( *args )
    if !args.empty?
      @sample = args.first
      self
    else
      if @sample.nil?
        begin
          @sample ||= Sampler.new( self ) do |value|
            do_format( value )
          end.compute
        rescue
          puts "for #{entity_class.name}"
          puts $!.message
          puts $!.backtrace
        ensure
          # if we don't know how to figure it out from the data, just return the label size
          @sample ||= self.label
        end
      end
      @sample
    end
  end

  # Called by Clevic::TableModel to get the tooltip value
  def tooltip_for( entity )
    cache_value_for( :tooltip, entity )
  end

  # TODO Doesn't do anything useful yet.
  def decoration_for( entity )
    nil
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

  def to_s
    "#{entity_class}.#{id}"
  end

  def inspect
    "#<Clevic::Field #{entity_class} id=#{id} attribute=#{attribute}>"
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
    @label ||= ( id || attribute ).to_s.humanize
  end

  # sensible display format defaults if they're not defined.
  def default_format!
    @format ||=
    case meta.andand.type
      when :time; '%H:%M'
      when :date; '%d-%h-%y'
      when :datetime; '%d-%h-%y %H:%M:%S'
      when :decimal, :float; "%.2f"
    end
  end

  # sensible edit format defaults if they're not defined.
  def default_edit_format!
    @edit_format ||=
    case meta.andand.type
      when :date; '%d-%h-%Y'
      when :datetime; '%d-%h-%Y %H:%M:%S'
    end || default_format!
  end

  # sensible alignment defaults if they're not defined.
  def default_alignment!
    @alignment ||=
    case meta.andand.type
      when :decimal, :integer, :float; :right
      when :boolean; :centre
      else :left
    end
  end

  # try to find a sensible display method
  # TODO this code shows up in the default UI builder as well.
  def default_display!
    candidates = %W{#{entity_class.name.downcase} name title username to_s}
    @display ||= candidates.find do |m|
      related_class.column_names.include?( m ) || related_class.method_defined?( m )
    end || raise( "Can't find one of #{candidates.inspect} in #{related_class.name}" )
  end

end

end
