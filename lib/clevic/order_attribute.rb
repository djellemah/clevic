=begin rdoc
Store the SQL order_by attributes with ascending and descending values
=end
# TODO don't use this anymore
class OrderAttribute
  attr_reader :direction, :attribute
  
  def initialize( entity_class, sql_order_fragment )
    @entity_class = entity_class
    if sql_order_fragment =~ /^(.*?\.)?(.*?) *asc$/i
      @direction = :asc
      @attribute = $2
    elsif sql_order_fragment =~ /^(.*?\.)?(.*?) *desc$/i
      @direction = :desc
      @attribute = $2
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
    "#{@entity_class.table_name}.#{attribute} #{direction.to_s}"
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
    "#{@entity_class.table_name}.#{attribute} #{reverse(direction).to_s}"
  end

  def ==( other )
    @entity_class == other.instance_eval( '@entity_class' ) and
    self.direction == other.direction and
    self.attribute == other.attribute
  end
end
