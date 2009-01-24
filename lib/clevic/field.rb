require 'gather.rb'

module Clevic

=begin rdoc
This defines a field in the UI, and how it hooks up to a field in the DB.
=end
class Field
  include Gather
  
  # The attribute on the AR entity that forms the basis for this field.
  # Accessing the returned attribute (using send, or the [] method on an entity)
  # will give a simple value, or another AR entity in the case of relational fields.
  # In other words, this is *not* the same as the name of the field in the DB, which
  # would have an _id suffix for relationships.
  property :attribute
  
  # For relational fields, a dot-separated path of attributes starting on the object returned by attribute.
  # Set by :display in options to the constructor. Paths longer than 1 element haven't been
  # tested much.
  # It can also be a block used to display the value of the field. This can be used to display 'virtual'
  # fields from related tables, or calculated fields.
  property :display
  
  # The label for the field. Defaults to the humanised field name.
  property :label
  
  # The UI delegate class for the field. In Qt, this is a subclass of AbstractItemDelegate.
  property :delegate
  
  # For relational fields, this is the class_name for the related AR entity.
  property :class_name
  
  # One of the alignment specifiers - :left, :centre, :right or :justified.
  property :alignment
  
  # something to do with the icon that Qt displays. Not implemented yet.
  property :decoration
  
  # The format string, formatted by strftime for date and time fields, by sprintf for others.
  # Defaults to something sensible for the type of the field.
  property :format
  
  # The format used for editing
  property :edit_format
  
  # Whether the field is currently visible or not.
  property :visible
  
  # Sample is used if the programmer wishes to provide a string that can be used
  # as the basis for calculating the width of the field. By default this will be
  # calculated from the database, but this may be an expensive operation. So we
  # have the option to override that if we wish.
  property :sample
  
  # set the field to read-only
  property :read_only
  
  # the foreground and background colors
  property :foreground, :background
  
  property :tooltip
  
  # for restricted fields
  property :set
  
  # default value for new records. Not sure how to populate it though
  property :default
  
  # properties for ActiveRecord options
  # There are actually from VALID_FIND_OPTIONS, but it's protected
  AR_FIND_OPTIONS = [ :conditions, :include, :joins, :limit, :offset, :order, :select, :readonly, :group, :from, :lock ]
  AR_FIND_OPTIONS.each{|x| property x}
  
  # Create a new Field object that displays the contents of a database field in
  # the UI using the given parameters.
  # - attribute is the symbol for the attribute on the entity_class.
  # - entity_class is the ActiveRecord class which this Field talks to.
  # - options is a hash of writable attributes in Field.
  def initialize( attribute, entity_class, options, &block )
    # sanity checking
    raise "attribute #{attribute.inspect} must be a symbol" unless attribute.is_a?( Symbol )
    raise "entity_class must be a descendant of ActiveRecord::Base" unless entity_class.ancestors.include?( ActiveRecord::Base )
    
    unless entity_class.has_attribute?( attribute ) or entity_class.instance_methods.include?( attribute.to_s )
      msg = <<EOF
#{attribute} not found in #{entity_class.name}. Possibilities are:
#{entity_class.attribute_names.join("\n")}
EOF
      raise msg
    end
    
    # set values
    @attribute = attribute
    @entity_class = entity_class
    @visible = true
    
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
    return nil if entity.nil?
    transform_attribute( entity.send( attribute ) )
  end
  
  # Apply display, to the given
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
  
  # return true if it's a date, a time or a datetime
  # cache result because the type won't change in the lifetime of the field
  def is_date_time?
    @is_date_time ||= [:time, :date, :datetime].include?( meta.type )
  end
  
  # return ActiveRecord::Base.columns_hash[attribute]
  # in other words an ActiveRecord::ConnectionAdapters::Column object,
  # or an ActiveRecord::Reflection::AssociationReflection object
  def meta
    @meta ||= @entity_class.columns_hash[attribute.to_s] || @entity_class.reflections[attribute]
  end
  
  # return the type of this attribute. Usually one of :string, :integer
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
  
  # Return the name of the database field for this Field, quoted for the dbms.
  def quoted_field
    quote_field( meta.name )
  end
  
  # Quote the given string as a field name for SQL.
  def quote_field( field_name )
    @entity_class.connection.quote_column_name( field_name )
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
  
  # format this value. Use strftime for date_time types, or % for everything else
  def do_format( value )
    if self.format != nil
      if is_date_time?
        value.strftime( format )
      else
        if self.format.is_a? Proc
          self.format.call( value )
        else
          self.format % value
        end
      end
    else
      value
    end
  end
  
  def do_edit_format( value )
    if self.edit_format != nil
      if is_date_time?
        value.strftime( edit_format )
      else
        self.edit_format % value
      end
    else
      value
    end
  end
  
  # return a sample for the field which can be used to size the UI field widget
  def sample( *args )
    if !args.empty?
      self.sample = *args
      return
    end
    
    if @sample.nil?
      self.sample =
      case meta.type
        # max width of 40 chars
        when :string, :text
          string_sample( 'n'*40 )
        
        when :date, :time, :datetime, :timestamp
          date_time_sample
        
        when :numeric, :decimal, :integer, :float
          numeric_sample
        
        # TODO return a width, or something like that
        when :boolean; 'W'
        
        when ActiveRecord::Reflection::AssociationReflection.class
          related_sample
        
        else
          puts "#{@entity_class.name}.#{attribute} is a #{meta.type.inspect}"
      end
        
      #~ if $options && $options[:debug]
        #~ puts "@sample for #{@entity_class.name}.#{attribute} #{meta.type}: #{@sample.inspect}"
      #~ end
    end
    # if we don't know how to figure it out from the data, just return the label size
    @sample || self.label
  end
  
  def self.conversion_blocks
    @conversion_blocks ||= {}
  end
  
  def self.value_for( *symbols, &conversion_block )
    symbols.each do |sym|
      #~ class_eval( "@#{}_conversion_block" ) = conversion_block || lambda{|x| x.to_s}
      conversion_blocks[sym] = = conversion_block || lambda{|x| x.to_s}
      name = sym.to_s
      line, st = __LINE__, <<-EOF
        def #{name}_for( entity )
          puts "#{name}: \#\{#{name}.inspect\}"
          
          for_retval =
          case #{name}
            when Proc; #{name}.call( entity ) unless entity.nil?
            when Symbol; entity.send( #{name} ) unless entity.nil?
            else; @#{name}_cache ||= self.class.conversion_blocks[:#{name}].call( #{name} )
          end
          puts "for_retval: \#\{for_retval.inspect\}"
          for_retval
        end
      EOF
      puts st
      class_eval st, __FILE__, line + 1
    end
  end
  
  value_for :tooltip

  # convert something that responds to to_s to a Qt::Color
  # or just return the argument if it's already a Qt::Color
  value_for( :background, :foreground ) do |string_or_color|
    puts "string_or_color: #{string_or_color.inspect}"
    case string_or_color
    when Qt::Color
      string_or_color
    else
      Qt::Color.new( string_or_color.to_s )
    end
  end
  
  def decoration_for( entity )
    nil
  end

protected

  def default_label!
    @label ||= attribute.to_s.humanize
  end

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

  def default_alignment!
    if @alignment.nil?
      @alignment =
      case meta.type
        when :decimal, :integer, :float; :right
        when :boolean; :centre
      end
    end
  end

private

  def format_result( result_set )
    unless result_set.size == 0
      obj = result_set[0][attribute]
      do_format( obj ) unless obj.nil?
    end
  end
  
  def string_sample( max_sample = nil, entity_class = @entity_class, field_name = meta.name )
    statement = <<-EOF
      select distinct #{quote_field field_name}
      from #{entity_class.table_name}
      where
        length( #{quote_field field_name} ) = (
          select max( length( #{quote_field field_name} ) )
          from #{entity_class.table_name}
        )
    EOF
    result_set = @entity_class.connection.execute statement
    unless result_set.entries.size == 0
      row = result_set[0]
      result = 
      case row
        when Array
          row[0]
        when Hash
          row.values[0]
      end
        
      if max_sample.nil?
        result
      else
        result.length < max_sample.length ? result : max_sample
      end
    end
  end
  
  def date_time_sample
    result_set = @entity_class.find_by_sql <<-EOF
      select #{quoted_field}
      from #{@entity_class.table_name}
      where #{quoted_field} is not null
      limit 1
    EOF
    format_result( result_set )
  end
  
  def numeric_sample
    # TODO Use precision from metadata, not for integers
    # returns nil for floats. So it's probably not useful
    #~ puts "meta.precision: #{meta.precision.inspect}"
    result_set = @entity_class.find_by_sql <<-EOF
      select max( #{quoted_field} )
      from #{@entity_class.table_name}
    EOF
    format_result( result_set )
  end
  
  def related_sample
    # TODO this isn't really the right way to do this
    return nil if meta.nil?
    if meta.klass.attribute_names.include?( attribute_path[1].to_s )
      string_sample( nil, meta.klass, attribute_path[1] )
    end
  end
  
end

end
