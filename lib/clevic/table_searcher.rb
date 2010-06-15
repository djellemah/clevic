module Clevic

=begin
Search for a record in the collection given a set of criteria. One of the
criteria will be a starting record, and the search method should return
the matching record next after this.
=end
class TableSearcher
  attr_reader :dataset, :search_criteria, :field
  
  # dataset is a Sequel::Dataset, which has an associated Sequel::Model
  # field is an instance of Clevic::Field
  # search_criteria responds to from_start?, direction, whole_words? and search_text
  def initialize( dataset, search_criteria, field )
    raise "field must be specified" if field.nil?
    raise "unknown order #{search_criteria.direction}" unless [:forwards, :backwards].include?( search_criteria.direction )
    raise "dataset has no model" unless dataset.respond_to?( :model )
    
    # set default dataset ordering if it's not there
    @dataset =
    if dataset.opts[:order].nil?
      dataset.order( dataset.model.primary_key )
    else
      dataset
    end
    
    @search_criteria = search_criteria
    @field = field
  end
  
  # start_entity is the entity to start from, ie any record found after it will qualify
  # return the first entity found that matches the criteria
  def search( start_entity = nil )
    search_dataset( start_entity ).first
  end

protected
  # return a Sequel expression for the name of the field to use as a comparison
  def search_field_expression
    if field.is_association?
      # for related tables
      unless [String,Symbol].include?( field.display.class )
        raise( "search field #{field.inspect} cannot search lambda display" ) 
      end
      
      raise "display not specified for #{field}" if field.display.nil?
      
      # TODO this will only work with a path value with no dots
      # otherwise the SQL gets complicated with joins etc
      related_class = eval field.meta.class_name
      related_class \
        .filter( related_class.primary_key.qualify( related_class.table_name ) => field.meta.key.qualify( field.entity_class.table_name ) ) \
        .select( field.display.to_sym )
    else
      # for this table
      field.attribute.to_sym
    end
  end
  
  # return an expression, or an array or expressions for representing search_criteria.search_text and whole_words?
  def search_text_expression
    if search_criteria.whole_words?
      [
        "% #{search_criteria.search_text} %",
        "#{search_criteria.search_text} %",
        "% #{search_criteria.search_text}",
        search_criteria.search_text
      ]
    else
      "%#{search_criteria.search_text}%"
    end
  end
  
  # Add the relevant conditions to use start_entity as the
  # entity where the search starts, ie the first one after it is found
  # start_entity is a model instance
  def find_from( dataset, start_entity )
    expression = build_recursive_comparison( start_entity )
    # need expression => true because most databases can't evaluate a
    # pure boolean expression - they need something to compare it to.
    dataset.filter( expression => true )
  end
  
  # return a dataset based on @dataset which filters on search_criteria
  def search_dataset( start_entity )
    likes = Array[*search_text_expression].map{|ste| Sequel::SQL::StringExpression.like(search_field_expression, ste)}
    rv = @dataset.filter( Sequel::SQL::BooleanExpression.new(:OR, *likes ) )
    
    # if we're not searching from the start, we need
    # to find the next match. Which is complicated from an SQL point of view.
    unless search_criteria.from_start?
      raise "start_entity cannot be nil when from_start is false" if start_entity.nil?
      # build up the ordering conditions
      rv = find_from( rv, start_entity )
    end
    
    # reverse order by direction if necessary
    rv = rv.reverse if search_criteria.direction == :backwards
    
    # return dataset
    rv
  end
  
  # recursively create a case statement to do the comparison
  # because and ... and ... and filters on *each* one rather than
  # consecutively.
  def build_recursive_comparison( start_entity, index = 0 )
    # end recursion
    return false if index == order_attributes.size
    
    # fetch the current order attribute and direction
    attribute, direction = order_attributes[index]
    value = start_entity.send( attribute )
    
    # build case statement using Sequel expressions, including recursion
    # pseudo-SQL is
    # case
    #   when attribute < value then true
    #   when attribute = value then #{build_recursive_comparison( operator, index+1 )}
    #   else false
    # end
    
    {
      # if values are unequal, comparison levels end here
      attribute.identifier.send( comparator(direction), value ) => true,
      # if the values are equal, move on to the next level of comparison
      { attribute => value } => build_recursive_comparison( start_entity, index+1 )
    }.case( false ) # the else (default) clause, ie we don't want to see these records
  end
  
  # return either > or < depending on both search_criteria.direction
  # and local_direction
  def comparator( local_direction = 1 )
    comparator_direction =
    case search_criteria.direction
      when :forwards; 1
      when :backwards; -1
    end * local_direction
    
    # 1 indexes >, -1 indexes <
    ['','>','<'][comparator_direction]
  end
  
  # returns a collection of [ attribute, (1|-1) ]
  # where 1 is forward/asc (>) and -1 is backward/desc (<)
  def order_attributes
    if @order_attributes.nil?
      @order_attributes =
      @dataset.opts[:order].map do |order_expr|
        case order_expr
          when Symbol; [ order_expr, 1 ]
          when Sequel::SQL::OrderedExpression; [ order_expr.expression, order_expr.descending ? -1 : 1 ]
          else
            raise "unknown order_expr: #{order_expr.inspect}"
        end
      end
    end
    @order_attributes
  end
end

end

