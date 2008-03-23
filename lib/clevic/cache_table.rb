# Fetch rows from the db on demand, rather than all up front
# TODO drop rows when they haven't been accessed for a while
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
  
end

class Array
  # return true if something is cached, false otherwise
  def cached_at?( index )
    !at(index).nil?
  end
end
