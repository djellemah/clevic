require 'clevic/sql_dialects.rb'

module Clevic

# TODO Needs major rework for Sequel
class TableSearcher
  attr_reader :entity_class, :order_attributes, :search_criteria, :field
  
  # entity_class is a descendant of ActiveRecord::Base
  # order_attributes is a collection of OrderAttribute objects
  # - field is an instance of Clevic::Field
  # - search_criteria responds to from_start?, direction, whole_words? and search_text
  def initialize( entity_class, order_attributes, search_criteria, field )
    raise "there must be at least one order_attribute" if order_attributes.nil? or order_attributes.empty?
    raise "field must be specified" if field.nil?
    raise "unknown order #{search_criteria.direction}" unless [:forwards, :backwards].include?( search_criteria.direction )
    @entity_class = entity_class
    @order_attributes = order_attributes
    @search_criteria = search_criteria
    @field = field
  end
  
  # start_entity is the entity to start from, ie any record found after it will qualify
  def search( start_entity = nil )
    search_field_name = 
    if field.is_association?
      # for related tables
      unless [String,Symbol].include?( field.display.class )
        raise( "search field #{field.inspect} cannot have a complex display" ) 
      end
      
      # TODO this will only work with a path value with no dots
      # otherwise the SQL gets complicated with joins etc
      field.display
    else
      # for this table
      entity_class.connection.quote_column_name( field.attribute.to_s )
    end
    
    # do the conditions for the search value
    @conditions = search_clause( search_field_name )
    
    # if we're not searching from the start, we need
    # to find the next match. Which is complicated from an SQL point of view.
    unless search_criteria.from_start?
      raise "start_entity cannot be nil when from_start is false" if start_entity.nil?
      # build up the ordering conditions
      find_from!( start_entity )
    end
    
    # otherwise ActiveRecord thinks that the % in the string
    # is for interpolations instead of treating it a the like wildcard
    conditions_value =
    if !@params.nil? and @params.size > 0
      [ @conditions, @params ]
    else
      @conditions
    end
    
    # find the first match
    entity_class.adaptor.find(
      :first,
      :conditions => conditions_value,
      :order => order,
      :joins => ( field.meta.name if field.is_association? )
    )
  end

protected
  include SqlDialects
  
  def quote_identifier( field_name )
    entity_class.connection.quote_column_name( field_name )
  end
  
  def quote_literal( value )
    entity_class.connection.quote_literal( value )
  end
  
  # recursively create a case statement to do the comparison
  # because and ... and ... and filters on *each* one rather than
  # consecutively.
  # operator is either '<' or '>'
  def build_recursive_comparison( operator, index = 0 )
    # end recursion
    return sql_boolean( false ) if index == order_attributes.size
    
    # fetch the current attribute
    attribute = order_attributes[index]
    
    # build case statement, including recursion
    st = <<-EOF
case
  when #{entity_class.table_name}.#{quote_identifier attribute} #{operator} :#{attribute} then #{sql_boolean true}
  when #{entity_class.table_name}.#{quote_identifier attribute} = :#{attribute} then #{build_recursive_comparison( operator, index+1 )}
  else #{sql_boolean false}
end
EOF
    # indent
    st.gsub!( /^/, '  ' * index )
  end
  
  # Add the relevant conditions to use start_entity as the
  # entity where the search starts, ie the first one after it is found
  # start_entity is an AR model instance
  # sets @params and @conditions
  def find_from!( start_entity )
    operator =
    case search_criteria.direction
      when :forwards; '>'
      when :backwards; '<'
    end
    
    # build the sql comparison where clause fragment
    comparison_sql = build_recursive_comparison( operator )
    
    # only Postgres seems to understand real booleans
    # everything else needs the big case statement to be compared
    # to something
    unless entity_class.connection.adapter_name == 'PostgreSQL'
      comparison_sql += " = #{sql_boolean true}"
    end
    
    # build parameter values
    @params ||= {}
    order_attributes.each {|x| @params[x.to_sym] = start_entity.send( x.attribute )}
    
    @conditions += " and " + comparison_sql
  end
  
  # get the search value parameter, in SQL format
  def search_clause( field_name )
    if search_criteria.whole_words?
      <<-EOF
      (
        #{field_name} #{like_operator} #{quote "% #{search_criteria.search_text} %"}
        or
        #{field_name} #{like_operator} #{quote "#{search_criteria.search_text} %"}
        or
        #{field_name} #{like_operator} #{quote "% #{search_criteria.search_text}"}
      )
      EOF
    else
      "#{field_name} #{like_operator} #{quote "%#{search_criteria.search_text}%"}"
    end
  end
  
  def ascending_order
    order_attributes.map{|x| x.to_sql}.join(',')
  end
  
  def descending_order
    order_attributes.map{|x| x.to_reverse_sql}.join(',')
  end
  
  def order
    case search_criteria.direction
      when :forwards; ascending_order
      when :backwards; descending_order
    end
  end
  
end

end
