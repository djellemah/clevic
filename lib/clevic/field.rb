module Clevic

=begin rdoc
This defines a field in the UI, and how it hooks up to a field in the DB.
=end
class Field
  attr_accessor :attribute, :path, :label, :delegate, :class_name, :alignment, :format
  attr_writer :sample
  
  def initialize( attribute, model_class, options )
    @attribute = attribute
    @model_class = model_class
    
    options.each do |key,value|
      self.send( "#{key}=", value ) if respond_to?( key )
    end
    @label ||= attribute.to_s.humanize
    
    if @format.nil?
      case meta.type
      when :time; @format = '%H:%M'
      when :date; @format = '%d-%h-%y'
      when :datetime; @format = '%d-%h-%y %H:%M:%S'
      when :decimal; @format = "%.2f"
      when :float; @format = "%.2f"
      end
    end
  end
  
  # return true if it's a date, a time or a datetime
  # cache result because the type won't change in the lifetime of the field
  def is_date_time?
    @is_date_time ||= [:time, :date, :datetime].include?( meta.type )
  end
  
  # return ActiveRecord::Base.columns_hash[attribute]
  # in other words an ActiveRecord::ConnectionAdapters::Column object
  def meta
    @model_class.columns_hash[attribute.to_s] || @model_class.reflections[attribute]
  end

  # return the name of the field for this Field, quoted for the dbms
  def quoted_field
    @model_class.connection.quote_column_name( meta.name )
  end

  def column
    [attribute.to_s, path].compact.join('.')
  end
  
  # return an array of the various attribute parts
  def attribute_path
    pieces = [ attribute.to_s ]
    pieces.concat( path.split( /\./ ) ) unless path.nil?
    pieces.map{|x| x.to_sym}
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
        when :string; string_sample
        # max width of 40 chars
        when :text; string_sample( 'n'*40 )
        
        when :date; date_time_sample
        when :time; date_time_sample
        when :datetime; date_time_sample
        
        when :numeric; numeric_sample
        when :decimal; numeric_sample
        when :integer; numeric_sample
        
        # TODO return a width, or something like that
        when :boolean; 'W'
        
        else
          puts "#{@model_class.name}.#{attribute} is a #{meta.type}"
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
    puts "meta.precision: #{meta.precision.inspect}"
    result_set = @model_class.find_by_sql <<-EOF
      select max( #{quoted_field} )
      from #{@model_class.table_name}
    EOF
    format_result( result_set )
  end
  
end

end
