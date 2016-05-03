require 'clevic/table_searcher'
require 'clevic/ordered_dataset'
require 'bsearch'

module Clevic

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

TODO figure out how to handle situations where the character set ordering
in the db and in Ruby are different.
=end
class CacheTable < Array

  include OrderedDataset

  # the number of records loaded in one call to the db
  attr_accessor :preload_count
  attr_reader :entity_class

  def initialize( entity_class, dataset = nil )
    @preload_count = 30
    @entity_class = entity_class
    # defined in OrderAttributes
    self.dataset = dataset || entity_class.dataset

    # size the array and fill it with nils. They'll be filled
    # in by the [] operator
    super( sql_count )
  end

  # The count of the records according to the db, which may be different to
  # the records in the cache
  def sql_count
    dataset.count
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
    offset = index < 0 ? index + sql_count : index

    # fetch self.preload_count records
    records = dataset.limit( preload_count, offset )
    records.each_with_index {|x,i| self[i+index] = x if !cached_at?( i+index )}

    # return the first one
    records.first
  end

  # return the entity at the given index. Fetch it from the
  # db if it isn't in this array yet
  def []( index )
    super( index ) || fetch_entity( index )
  end

  # Make a new instance based on the current dataset.
  # Unless new_dataset is specified, pass the dataset
  # to the block, and use the return
  # value from the block as the new dataset.
  #
  # This is so that filter of datasets can be based on the
  # existing one, but it's easy to go back to previous data
  # sets if necessary.
  # TODO write tests for both cases.
  def renew( new_dataset = nil, &block )
    if new_dataset && block_given?
      raise "Passing a new dataset and a modification block doesn't make sense."
    end

    if block_given?
      self.class.new( entity_class, block.call( dataset ) )
    else
      self.class.new( entity_class, new_dataset || dataset )
    end
  end

  # key is what we're searching for. candidate
  # is what the current candidate is. direction is 1
  # for sorted ascending, and -1 for sorted descending
  # TODO retrieve nulls first/last from dataset. In sequel (>3.13.0)
  # this is related to entity_class.filter( :release_date.desc(:nulls=>:first), :name.asc(:nulls=>:last) )
  def compare( key, candidate, direction )
    if ( key_nil = key.nil? ) || candidate.nil?
      if key == candidate
        # both nil, ie equal
        0
      else
        # assume nil is sorted greater
        # TODO this should be retrieved from the db
        # ie candidate(nil) <=> key is 1
        # and key <=> candidate(nil) is -1
        key_nil ? -1 : 1
      end
    else
      candidate <=> key
    end * direction
    # reverse the result if we're searching a desc attribute,
    # where direction will be -1
  end

  # find the index for the given entity, using a binary search algorithm (bsearch).
  # The order_by ActiveRecord style options are used to do the binary search.
  # nil is returned if the entity is nil
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
          # result from the block should be in [-1,0,1],
          # similar to candidate <=> entity
          key, direction = attribute
          if result == 0
            return nil unless entity.respond_to? key
            return nil unless candidate.respond_to? key

            # compare taking ordering direction into account
            retval = compare( entity.send( key ), candidate.send( key ), direction )

            # exit now because we have a difference
            next( retval ) if retval != 0

            # otherwise try with the next order attribute
            retval
          else
            # recurse out because we have a difference already
            result
          end
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
