require 'qtext/flags.rb'

require 'clevic/field_builder.rb'

module Clevic

=begin rdoc
This defines a field in the UI, and how it hooks up to a field in the DB.
=end
class Field
  include QtFlags
  
  attr_accessor :attribute, :path, :label, :delegate, :class_name
  attr_accessor :alignment, :format, :tooltip, :path_block
  attr_accessor :visible
  
  attr_writer :sample, :read_only
  
  # attribute is the symbol for the attribute on the model_class
  def initialize( attribute, model_class, options )
    # sanity checking
    unless model_class.has_attribute?( attribute ) or model_class.instance_methods.include?( attribute.to_s )
      msg = <<EOF
#{attribute} not found in #{model_class.name}. Possibilities are:
#{model_class.attribute_names.join("\n")}
EOF
      raise msg
    end
    
    # set values
    @attribute = attribute
    @model_class = model_class
    @visible = true
    
    options.each do |key,value|
      self.send( "#{key}=", value ) if respond_to?( "#{key}=" )
    end
    
    # TODO could convert everything to a block here, even paths
    if options[:display].kind_of?( Proc )
      @path_block = options[:display]
    else
      @path = options[:display]
    end
    
    # default the label
    @label ||= attribute.to_s.humanize
    
    # default formats
    if @format.nil?
      case meta.type
        when :time; @format = '%H:%M'
        when :date; @format = '%d-%h-%y'
        when :datetime; @format = '%d-%h-%y %H:%M:%S'
        when :decimal, :float; @format = "%.2f"
      end
    end
    
    # default alignments
    if @alignment.nil?
      @alignment =
      case meta.type
        when :decimal, :integer, :float; qt_alignright
        when :boolean; qt_aligncenter
      end
    end
  end
  
  # Return the attribute value for the given entity, which will probably
  # be an ActiveRecord instance
  def value_for( entity )
    return nil if entity.nil?
    transform_attribute( entity.send( attribute ) )
  end
  
  # apply path, or path_block, to the given
  # attribute value. Otherwise just return
  # attribute_value itself
  def transform_attribute( attribute_value )
    return nil if attribute_value.nil?
    case
      when !path_block.nil?
        path_block.call( attribute_value )
        
      when !path.nil?
        attribute_value.evaluate_path( path.split( /\./ ) )
        
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
    @model_class.columns_hash[attribute.to_s] || @model_class.reflections[attribute]
  end

  # return true if this field can be used in a filter
  # virtual fields (ie those that don't exist in this field's
  # table) can't be filtered on.
  def filterable?
    !meta.nil?
  end
  
  # return the name of the field for this Field, quoted for the dbms
  def quoted_field
    @model_class.connection.quote_column_name( meta.name )
  end

  # return the result of the attribute + the path
  def column
    [attribute.to_s, path].compact.join('.')
  end
  
  # return an array of the various attribute parts
  def attribute_path
    pieces = [ attribute.to_s ]
    pieces.concat( path.split( /\./ ) ) unless path.nil?
    pieces.map{|x| x.to_sym}
  end
  
  # is the field read-only. Defaults to false.
  def read_only?
    @read_only || false
  end
  
  # format this value. Use strftime for date_time types, or % for everything else
  def do_format( value )
    if self.format != nil
      if is_date_time?
        value.strftime( format )
      else
        self.format % value
      end
    else
      value
    end
  end
  
  # return a sample for the field which can be used to size a column in the table
  def sample
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
        
        when ActiveRecord::Reflection::AssociationReflection
          #TODO width for relations
        
        else
          puts "#{@model_class.name}.#{attribute} is a #{meta.type.inspect}"
      end
        
      if $options[:debug]  
        puts "@sample for #{@model_class.name}.#{attribute} #{meta.type}: #{@sample.inspect}"
      end
    end
    # if we don't know how to figure it out from the data, just return the label size
    @sample || self.label
  end

private

  def format_result( result_set )
    unless result_set.size == 0
      obj = result_set[0][attribute]
      unless obj.nil?
        do_format( obj )
      end
    end
  end
  
  def string_sample( max_sample = nil )
    result_set = @model_class.connection.execute <<-EOF
      select distinct #{quoted_field}
      from #{@model_class.table_name}
      where
        length( #{quoted_field} ) = (
          select max( length( #{quoted_field} ) )
          from #{@model_class.table_name}
        )
    EOF
    unless result_set.entries.size == 0
      result = result_set[0][0]
      if max_sample.nil?
        result
      else
        result.length < max_sample.length ? result : max_sample
      end
    end
  end
  
  def date_time_sample
    result_set = @model_class.find_by_sql <<-EOF
      select #{quoted_field}
      from #{@model_class.table_name}
      where #{quoted_field} is not null
      limit 1
    EOF
    format_result( result_set )
  end
  
  def numeric_sample
    # TODO Use precision from metadata, not for integers
    # returns nil for floats. So it's probably not useful
    #~ puts "meta.precision: #{meta.precision.inspect}"
    result_set = @model_class.find_by_sql <<-EOF
      select max( #{quoted_field} )
      from #{@model_class.table_name}
    EOF
    format_result( result_set )
  end
  
end

end
