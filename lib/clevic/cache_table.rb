require 'clevic/table_searcher.rb'
require 'clevic/order_attribute.rb'
require 'bsearch'

=begin rdoc
Fetch rows from the db on demand, rather than all up front.

Being able to change the recordset on the fly and still find a previously
known entity in the set requires a defined ordering, so if no ordering
is specified, the primary key of the entity will be used.

It hasn't been tested with compound primary keys.

#--

TODO drop rows when they haven't been accessed for a while

TODO how to handle a quickly-changing underlying table? invalidate cache
for each call?

TODO use Sequel instead of order_attributes
=end
class CacheTable < Array
  # the number of records loaded in one call to the db
  attr_accessor :preload_count
  attr_reader :find_options, :entity_class
  
  def initialize( entity_class, find_options = {} )
    @preload_count = 20
    # must be before sanitise_options
    @entity_class = entity_class
    # must be before anything that uses options
    @find_options = (find_options || {}).clone
    sanitise_options!
    
    # size the array and fill it with nils. They'll be filled
    # in by the [] operator
    @row_count = sql_count
    super( @row_count )
  end
  
  # The count of the records according to the db, which may be different to
  # the records in the cache
  def sql_count
    entity_class.adaptor.count( find_options.reject{|k,v| k == :order} )
  end
  
  # Return the set of OrderAttribute objects for this collection.
  # If no order attributes are specified, the primary key will be used.
  # TODO what about compound primary keys?
  def order_attributes
    # This is sorted in @options[:order], so use that for the search
    if @order_attributes.nil?
      @order_attributes = find_options[:order].to_s.split( /, */ ).map{|x| OrderAttribute.new(@entity_class, x)}
      
      # add the primary key if nothing is specified
      # because we need an ordering of some kind otherwise
      # index_for_entity will not work
      unless @order_attributes.any? {|x| x.attribute.to_s == entity_class.primary_key.to_s }
        @order_attributes << OrderAttribute.new( entity_class, entity_class.primary_key )
      end
    end
    @order_attributes
  end
  
  # add an id to options[:order] if it's not in there
  # make sure options[:conditions] uses db values rather than objects
  # ie convert { :debit => DebitObject<...> } to { :debit_id => 5 }
  def sanitise_options!
    # make sure we have a string here, even if it's blank
    # value would be a ,-separated list of order by fields (expressions?)
    find_options[:order] ||= ''
    
    # recreate the options[:order] entry to include default
    find_options[:order] = order_attributes.map{|x| x.to_sql}.join(',')
    
    # make sure objects are converted to ids
    if find_options.has_key?( :conditions ) && find_options[:conditions].is_a?( Hash )
      conditions = find_options[:conditions].map do |key,value|
        metadata = entity_class.meta[key]
        if metadata.association?
          [metadata.key, value.send( value.primary_key )]
        else
          [key,value]
        end
      end
      find_options[:conditions] = Hash[ *conditions.flatten ]
    end
  end

  # Execute the block with the specified preload_count,
  # and restore the existing one when done.
  # Return the value of the block
  def preload_limit( limit, &block )
    old_limit = preload_count
    self.preload_count = limit
    retval = yield
    self.preload_count = old_limit
    retval
  end
  
  # Fetch the entity for the given index from the db, and store it
  # in the array. Also, preload preload_count records to avoid subsequent
  # hits on the db
  def fetch_entity( index )
    # calculate negative indices for the SQL offset
    offset = index < 0 ? index + @row_count : index
    
    # fetch self.preload_count records
    records = entity_class.adaptor.find( :all, find_options.merge( :offset => offset, :limit => preload_count ) )
    records.each_with_index {|x,i| self[i+index] = x if !cached_at?( i+index )}
    
    # return the first one
    records[0]
  end
  
  # return the entity at the given index. Fetch it from the
  # db if it isn't in this array yet
  def []( index )
    super( index ) || fetch_entity( index )
  end
  
  # make a new instance that has the attributes of this one, but an empty
  # data set. pass in ActiveRecord options to filter.
  # TODO use Sequel::Dataset
  def renew( args = nil )
    clear
    self.class.new( entity_class, args || find_options )
  end
  
  # find the index for the given entity, using a binary search algorithm (bsearch).
  # The order_by ActiveRecord style options are used to do the binary search.
  # 0 is returned if the entity is nil
  # nil is returned if the array is empty
  def index_for_entity( entity )
    return nil if size == 0 || entity.nil?
    
    # only load one record at a time, because mostly we only
    # need one for the binary seach. No point in pulling several out.
    preload_limit( 1 ) do
      # do the binary search based on what we know about the search order
      bsearch do |candidate|
        # find using all sort attributes
        order_attributes.inject(0) do |result,attribute|
          if result == 0
            method = attribute.attribute.to_sym
            # compare taking ordering direction into account
            retval =
            if attribute.direction == :asc
              candidate.send( method ) <=> entity.send( method )
            else
              entity.send( method ) <=> candidate.send( method )
            end
            # exit now because we have a difference
            next( retval ) if retval != 0
            
            # otherwise try with the next order attribute
            retval
          else
            # they're equal, so try next order attribute
            result
          end
        end
      end
    end
  end
end

# This is part of Array in case the programmer wants to use
# a simple array instead of a CacheTable.
class Array
  # For use with CacheTable. Return true if something is cached, false otherwise
  def cached_at?( index )
    !at(index).nil?
  end
  
  def search
    raise "not implemented"
  end
end
