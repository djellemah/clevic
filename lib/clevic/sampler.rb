require 'clevic/generic_format.rb'
require 'andand'

module Clevic

# Calculate a string sample for a particular Field
class Sampler
  def initialize( entity_class, field_name, display, &block )
    @entity_class = entity_class
    @field_name = field_name
    @display = display
    @format_block = block
  end
  
  attr_reader :entity_class, :field_name, :display
  
  def meta
    @meta ||= entity_class.meta[field_name]
  end
  
  # return a string which is representative of the width of the field
  def compute
    case meta.type
    when :string, :text
      string_sample
    
    when :date, :time, :datetime, :timestamp
      date_time_sample
    
    when :numeric, :decimal, :integer, :float
      numeric_sample
    
    # TODO return a width, or something like that
    when :boolean; 'W'
    
    when :many_to_one
      related_sample
    
    else
      puts "Sampler#compute can't figure out sample for #{entity_class.name}.#{field_name} because it's a #{meta.type.inspect}"
    
    end
  end
  
  def do_format( value )
    @format_block.call( value )
  end
  
  # default to max length of 20
  def string_sample
    'N' * ( entity_class.max( :length.sql_function( field_name ) ).andand.to_i || 20 )
  end
  
  def date_time_sample
    sample_date = entity_class \
      .filter( ~{ field_name => nil } ) \
      .select( field_name ) \
      .limit(1) \
      .single_value
    ;
    # replace all letters with 'N'
    do_format( sample_date || Date.today ).gsub( /[[:alpha:]]/, 'N' )
  end
  
  def numeric_sample
    max = entity_class.max( field_name )
    min = entity_class.min( field_name )
    max_length = [ do_format( min ).to_s, do_format( max ).to_s ].map( &:length ).max
    '9' * ( max_length || 5 )
  end
  
  def related_sample
    if display.is_a?( Symbol )
      Sampler.new( eval( meta.class_name ), display, nil, &@format_block ).compute
    end
  end
end

end
