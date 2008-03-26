require 'bsearch'

=begin rdoc
Store the SQL order_by attributes with ascending and descending values
=end
class OrderAttribute
  attr_reader :direction, :attribute
  
  def initialize( sql_order_fragment )
    if sql_order_fragment =~ /(.*?) *asc/
      @direction = :ascending
      @attribute = $1
    elsif sql_order_fragment =~ /(.*?) *desc/
      @direction = :descending
      @attribute = $1
    else
      @direction = :ascending
      @attribute = sql_order_fragment
    end
  end
  
  def to_s
    attribute
  end
end

=begin rdoc
Fetch rows from the db on demand, rather than all up front
---
TODO drop rows when they haven't been accessed for a while
=end
class CacheTable < Array
  
  def initialize( model_class, find_options = {} )
    @row_count = model_class.count( :conditions => find_options[:conditions] )
    super(@row_count)
    @options = find_options
    @model_class = model_class
  end
  
  def []( index )
    if super(index).nil?
      # calculate negative indices for the SQL offset
      offset = index < 0 ? index + @row_count : index
      self[index] = @model_class.find( :first, @options.merge( :offset => offset ) )
      #~ if index >= ( size - 3 ) || index < 0
        #~ obj = self[index]
        #~ puts "offset: #{offset.inspect}"
        #~ puts "index: #{index.inspect}"
        #~ puts "obj: #{obj.inspect}"
      #~ end
    else
      super(index)
    end
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
    @order_attributes ||= @options[:order].to_s.split( /, */ ).map{|x| OrderAttribute.new(x)}
  end
  
  # find the index for the given entity, using a binary search algorithm (bsearch).
  # The order_by ActiveRecord style options are used to do the binary search.
  # 0 is returned if the entity is nil
  def index_for_entity( entity )
    return 0 if entity.nil?
    
    found_index = bsearch_first do |x|
      # sort by all attributes
      order_attributes.inject(0) do |result,attribute|
        if result == 0
          if attribute.direction == :ascending
            x.send( attribute.attribute ) <=> entity.send( attribute.attribute )
          else
            entity.send( attribute.attribute ) <=> x.send( attribute.attribute )
          end
        else
          result
        end
      end
    end
  end
  
end

class Array
  # return true if something is cached, false otherwise
  def cached_at?( index )
    !at(index).nil?
  end
end
