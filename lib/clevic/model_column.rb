=begin rdoc
Field metadata class. Includes information for type, reflections etc.

Also, it eases the migration from AR to Sequel, which returns metadata as
a hash instead of a class.
=end

class ModelColumn
  # these are from AR
  attr_accessor :primary, :scale, :sql_type, :name, :precision, :default, :type, :meta

  attr_writer :limit

  # if it's not here, it's probably from Sequel, so figure it out from
  # the db_type
  def limit
    unless @limit
      db_type =~ /\((\d+)\)/
      @limit = $1.to_i
    end
    @limit
  end

  # these are from Sequel::Model.columns_hash
  attr_accessor :ruby_default, :primary_key, :allow_null, :db_type

  # sequel::Model.reflections
  attr_accessor :key, :eager_block, :type, :eager_grapher, :before_add, :model, :graph_join_type, :class_name, :before_remove, :eager_loader, :uses_composite_keys, :order_eager_graph, :dataset, :cartesian_product_number, :after_add, :cache, :keys, :after_remove, :extend, :graph_conditions, :name, :orig_opts, :after_load, :before_set, :after_set, :reciprocal, :reciprocal_type

  # for many_to_one targets
  attr_accessor :primary_keys

  # TODO not sure where these are from
  attr_accessor :order, :class, :conditions

  # new in sequel 3.25.0
  attr_accessor :block

  # new in sequel 3.30.0
  attr_accessor :graph_alias_base
  attr_accessor :qualified_key

  # For Sequel many_to_many
  attr_accessor :left_key,
    :left_keys,
    :right_key,
    :right_keys,
    :left_primary_key,
    :left_primary_keys,
    :uses_left_composite_keys,
    :uses_right_composite_keys,
    :cartesian_product_number,
    :join_table,
    :left_key_alias,
    :graph_join_table_conditions,
    :graph_join_table_join_type

  # added by us
  attr_accessor :association
  def association?; association; end

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

  def related_class
    @related_class ||= eval class_name
  end
end
