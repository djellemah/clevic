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
      obj = @model_class.find( :first, @options.merge( :offset => index ) )
      self[index] = obj
    else
      super(index)
    end
  end

end
