require 'rubygems'
require 'active_record'
require 'active_record/dirty.rb'
require 'bsearch'

=begin rdoc
Store the SQL order_by attributes with ascending and descending values
=end
class OrderAttribute
  attr_reader :direction, :attribute
  
  def initialize( model_class, sql_order_fragment )
    @model_class = model_class
    if sql_order_fragment =~ /.*\.(.*?) *asc/
      @direction = :asc
      @attribute = $1
    elsif sql_order_fragment =~ /.*\.(.*?) *desc/
      @direction = :desc
      @attribute = $1
    else
      @direction = :asc
      @attribute = sql_order_fragment
    end
  end
  
  # return ORDER BY field name
  def to_s
    @string ||= attribute
  end
  
  def to_sym
    @sym ||= attribute.to_sym
  end
  
  # return 'field ASC' or 'field DESC', depending
  def to_sql
    "#{@model_class.table_name}.#{attribute} #{direction.to_s}"
  end
  
  def reverse( direction )
    case direction
      when :asc; :desc
      when :desc; :asc
      else; raise "unknown direction #{direction}"
    end
  end
  
  # return the opposite ASC or DESC from to_sql
  def to_reverse_sql
    "#{@model_class.table_name}.#{attribute} #{reverse(direction).to_s}"
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
  # the number of records loaded in one call to the db
  attr_accessor :preload_count
  attr_reader :options, :model_class
  
  def initialize( model_class, find_options = {} )
    @preload_count = 20
    # must be before sanitise_options
    @model_class = model_class
    # must be before anything that uses options
    @options = sanitise_options( find_options )
    
    # size the array and fill it with nils. They'll be filled
    # in by the [] operator
    @row_count = sql_count
    super(@row_count)
  end
  
  # The count of the records according to the db, which may be different to
  # the records in the cache
  def sql_count
    @model_class.count( :conditions => @options[:conditions] )
  end
  
  def order
    @options[:order]
  end
  
  def reverse_order
    @order_attributes.map{|x| x.to_reverse_sql}.join(',')
  end
  
  def quote_column( field_name )
    @model_class.connection.quote_column_name( field_name )
  end
  
  # return a string containing the correct
  # boolean value depending on the DB adapter
  # because Postgres wants real true and false in complex statements, not 't' and 'f'
  def sql_boolean( value )
    case model_class.connection.adapter_name
      when 'PostgreSQL'
        value ? 'true' : 'false'
      else; 'like'
        value ? model_class.connection.quoted_true : model_class.connection.quoted_false
    end
  end
  
  # recursively create a case statement to do the comparison
  # because and ... and ... and filters on *each* one rather than
  # consecutively.
  # operator is either '<' or '>'
  def build_recursive_comparison( operator, index = 0 )
    # end recursion
    return sql_boolean( false ) if index == @order_attributes.size
    
    # fetch the current attribute
    attribute = @order_attributes[index]
    
    # build case statement, including recusion
    st = <<-EOF
case
  when #{quote_column attribute} #{operator} :#{attribute} then #{sql_boolean true}
  when #{quote_column attribute} = :#{attribute} then #{build_recursive_comparison( operator, index+1 )}
  else #{sql_boolean false}
end
EOF
    st.gsub!( /^/, '  ' * index )
  end
  
  # return a Hash containing
  # :sql => the sql statement to be used as part of a where clause
  # :params => the parameters corresponding to :sql
  # entity is an AR model object
  # direction is either :forwards or :backwards
  def build_sql_find( entity, direction )
    operator =
    case direction
      when :forwards; '>'
      when :backwards; '<'
      else; raise "unknown direction #{direction.inspect}"
    end
    
    # build the sql comparison where clause fragment
    sql = build_recursive_comparison( operator )
    
    # only Postgres seems to understand real booleans
    # everything else needs the big case statement to be compared
    # to something
    unless model_class.connection.adapter_name == 'PostgreSQL'
      sql += " = #{sql_boolean true}"
    end
    
    # build parameter values
    params = {}
    @order_attributes.each {|x| params[x.to_sym] = entity.send( x.attribute )}
    puts sql
    puts params.inspect
    { :sql => sql, :params => params }
  end
  
  # add an id to options[:order] if it's not in there
  # also create @order_attributes
  def sanitise_options( options )
    options[:order] ||= ''
    @order_attributes = options[:order].split( /, */ ).map{|x| OrderAttribute.new(@model_class, x)}
    
    # add the primary key if nothing is specified
    # because we need an ordering of some kind otherwise
    # index_for_entity will not work
    if !@order_attributes.any? {|x| x.attribute == @model_class.primary_key }
      @order_attributes << OrderAttribute.new( @model_class, @model_class.primary_key )
    end
    
    # recreate the options[:order] entry
    options[:order] = @order_attributes.map{|x| x.to_sql}.join(',')
    
    # give back the sanitised options
    options
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
    records = @model_class.find( :all, @options.merge( :offset => offset, :limit => preload_count ) )
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
  # data set. pass in ActiveRecord options to filter
  def renew( options = {} )
    clear
    self.class.new( @model_class, @options.merge( options ) )
  end
  
  # Return the set of OrderAttribute objects for this collection
  def order_attributes
    # This is sorted in @options[:order], so use that for the search
    if @order_attributes.nil?
      @order_attributes = @options[:order].to_s.split( /, */ ).map{|x| OrderAttribute.new(@model_class, x)}
      
      # add the primary key if nothing is specified
      # because we need an ordering of some kind otherwise
      # index_for_entity will not work
      if !@order_attributes.any? {|x| x.attribute == @model_class.primary_key }
        @order_attributes << OrderAttribute.new( @model_class, @model_class.primary_key )
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
    return nil if entity.nil?
    
    # only load one record at a time
    preload_limit( 1 ) do
      #~ puts "entity: #{entity.inspect}"
      # do the binary search based on what we know about the search order
      bsearch do |candidate|
        #~ puts "candidate: #{candidate.inspect}"
        # find using all sort attributes
        order_attributes.inject(0) do |result,attribute|
          if result == 0
            method = attribute.attribute.to_sym
            # compare taking ordering direction into account
            retval =
            if attribute.direction == :asc
              #~ candidate.send( method ) <=> entity.send( method )
              candidate[method] <=> entity[method]
            else
              #~ entity.send( method ) <=> candidate.send( method )
              entity[method] <=> candidate[method]
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
  
  def delete_at( index )
    retval = super
    if self.size == 0
      self << @model_class.new
    end
    retval
  end
  
end

class Array
  # For use with CacheTable. Return true if something is cached, false otherwise
  def cached_at?( index )
    !at(index).nil?
  end
end
