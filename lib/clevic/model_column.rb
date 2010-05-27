=begin rdoc
Field metadata class. Includes information for type, reflections etc.

Also, it eases the migration from AR to Sequel, which returns metadata as
a hash instead of a class.
=end
class ModelColumn
  # these are from AR
  attr_accessor :primary, :scale, :sql_type, :name, :precision, :default, :limit, :type, :meta
  
  # these are from Sequel::Model.columns_hash
  attr_accessor :ruby_default, :primary_key, :allow_null, :db_type
  
  # sequel::Model.reflections
  attr_accessor :key, :eager_block, :type, :eager_grapher, :before_add, :model, :graph_join_type, :class_name, :before_remove, :eager_loader, :uses_composite_keys, :order_eager_graph, :dataset, :cartesian_product_number, :after_add, :cache, :keys, :after_remove, :extend, :graph_conditions, :name, :orig_opts, :after_load
  
  # for many_to_one targets
  attr_accessor :primary_keys
  
  # TODO not sure where these are from
  attr_accessor :order, :class, :conditions
  
  def initialize( name, hash )
    @hash = hash
    @hash.each do |key,value|
      send( "#{key}=", value )
    end
    
    # must be after hash so it takes precedence
    @name = name
  end
  
  def name
    @name
  end
end
