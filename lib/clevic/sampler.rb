require 'clevic/generic_format.rb'
require 'andand'

module Clevic

# This is used as part of the process of calculating the width
# of a field in the UI. Since the font is important, this computes
# a string value for a field that can be given to the font metrics
# for a framework. Uses various heuristics to compute the string
# values for different kinds of fields.
class Sampler
  # display is only used for relational fields
  def initialize( field, &format_block )
    @field = field
    @format_block = format_block
  end
  attr_reader :field

  def entity_class
    field.entity_class
  end

  def field_name
    field.attribute
  end

  def display
    field.display
  end

  def meta
    field.meta
  end

  # return a string which is representative of the width of the field
  def compute
    if field.set
      # choose the longest value in the set
      set = field.set_for( entity_class.first )
      if set.is_a?( Hash )
        set.values
      else
        set
      end. \
      max{|a,b| a.to_s.length <=> b.to_s.length }.upcase
    else
      # choose samples based on the type of the field
      case meta.type
      when :boolean
        field.label

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
        if meta.type != NilClass
          raise "Sampler#compute can't figure out sample for #{entity_class.name}.#{field_name} because it's a #{meta.type.inspect}"
        end
      end
    end
  end

  def do_format( value )
    @format_block.call( value )
  end

  # default to max length of 20
  def string_sample
    'N' * ( entity_class.max( :length.sql_function( field_name ) ).andand.to_i || 20 )
  end
  
  def sample_date_time
    ds = entity_class \
      .filter( ~{ field_name => nil } ) \
      .select( field_name ) \
      .limit(1)
    # can't use single-value here because the typecast_on_load
    # isn't called unless we access the value via the entity object
    ds.first.send( field_name )
  end
  
  def date_time_sample
    # replace all letters with 'N'
    # and numbers with 8
    do_format( sample_date_time || Date.today ).andand.gsub( /[[:alpha:]]/, 'N' ).gsub( /\d/, '8' )
  end
  
  def numeric_sample
    max = entity_class.max( field_name )
    min = entity_class.min( field_name )
    max_length = [ do_format( min ).to_s, do_format( max ).to_s ].map( &:length ).max
    '9' * ( max_length || 5 )
  end
  
  def related_sample
    if display.respond_to?( :to_sym )
      Sampler.new( eval( meta.class_name ), display.to_sym, nil, &@format_block ).compute
    end
  end
end

end
