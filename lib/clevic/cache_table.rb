require 'rubygems'
require 'active_record'
require 'active_record/dirty.rb'
require 'bsearch'

=begin rdoc
Store the SQL order_by attributes with ascending and descending values
=end
class OrderAttribute
  attr_reader :direction, :attribute
  
  def initialize( sql_order_fragment )
    if sql_order_fragment =~ /(.*?) *asc/
      @direction = :asc
      @attribute = $1
    elsif sql_order_fragment =~ /(.*?) *desc/
      @direction = :desc
      @attribute = $1
    else
      @direction = :asc
      @attribute = sql_order_fragment
    end
  end
  
  # return ORDER BY field name
  def to_s
    attribute
  end
  
  # return 'field ASC' or 'field DESC', depending
  def to_sql
    "#{attribute} #{direction.to_s}"
  end
end

=begin rdoc
Fetch rows from the db on demand, rather than all up front.

Being able to change the recordset on the fly and still find a previously
known entity in the set requires a defined ordering, so if no ordering
is specified, the primary key of the entity will be used.

It hasn't been tested with compound primary keys.
--
TODO drop rows when they haven't been accessed for a while

TODO how to handle a quickly-changing underlying table? invalidate cache
for each call?
=end
class CacheTable < Array
  
  def initialize( model_class, find_options = {} )
    # must be before sanitise_options
    @model_class = model_class
    # must be before anything that uses options
    @options = sanitise_options( find_options )
    
    # size the array and fill it with nils. They'll be filled
    # in by the [] operator
    @row_count = model_class.count( :conditions => @options[:conditions] )
    super(@row_count)
  end
  
  # add an id to options[:order] if it's not in there
  # also create @order_attributes
  def sanitise_options( options )
    options[:order] ||= ''
    @order_attributes = options[:order].split( /, */ ).map{|x| OrderAttribute.new(x)}
    
    # add the primary key if nothing is specified
    # because we need an ordering of some kind otherwise
    # index_for_entity will not work
    if !@order_attributes.any? {|x| x.attribute == @model_class.primary_key }
      @order_attributes << OrderAttribute.new( @model_class.primary_key )
    end
    
    # recreate the options[:order] entry
    options[:order] = @order_attributes.map{|x| x.to_sql}.join(',')
    
    # give back the sanitised options
    options
  end
  
  # fetch the entity for the given index from the db, and store it
  # in the array
  def fetch_entity( index )
    # calculate negative indices for the SQL offset
    offset = index < 0 ? index + @row_count : index
    # fetch the entity and store it
    self[index] = @model_class.find( :first, @options.merge( :offset => offset ) )
    #~ if index >= ( size - 3 ) || index < 0
      #~ obj = self[index]
      #~ puts "offset: #{offset.inspect}"
      #~ puts "index: #{index.inspect}"
      #~ puts "obj: #{obj.inspect}"
    #~ end
  end
  
  # return the entity at the given index. Fetch it from the
  # db if it isn't in this array yet
  def []( index )
    super( index ) || fetch_entity( index )
  end
  
  # make a new instance that has the attributes of this one, but an empty
  # data set. pass in ActiveRecord options to filter
  def renew( options = {} )
    clear
    self.class.new( @model_class, @options.merge( options ) )
  end
  
  # Return the set of OrderAttribute objects for this collection
  def order_attributes
    # This is sorted in @options[:order], so use that for the search
    if @order_attributes.nil?
      @order_attributes = @options[:order].to_s.split( /, */ ).map{|x| OrderAttribute.new(x)}
      
      # add the primary key if nothing is specified
      # because we need an ordering of some kind otherwise
      # index_for_entity will not work
      if !@order_attributes.any? {|x| x.attribute == @model_class.primary_key }
        @order_attributes << OrderAttribute.new( @model_class.primary_key )
      end
    end
    @order_attributes
  end
  
  # find the index for the given entity, using a binary search algorithm (bsearch).
  # The order_by ActiveRecord style options are used to do the binary search.
  # 0 is returned if the entity is nil
  # nil is returned if the array is empty
  def index_for_entity( entity )
    return nil if size == 0
    return 0 if entity.nil?
    
    # do the binary search base on what we know about the search order
    found_index = bsearch_first do |x|
      # sort by all attributes
      order_attributes.inject(0) do |result,attribute|
        if result == 0
          # try to return either 1 or -1.
          if attribute.direction == :asc
            x.send( attribute.attribute ) <=> entity.send( attribute.attribute )
          else
            entity.send( attribute.attribute ) <=> x.send( attribute.attribute )
          end
        else
          # they're equal, so keep trying or end
          result
        end
      end
    end
  end
  
end

class Array
  # For use with CacheTable. Return true if something is cached, false otherwise
  def cached_at?( index )
    !at(index).nil?
  end
end
