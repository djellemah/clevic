=begin rdoc
This responds to the same methods as ActiveRecord::ConnectionAdapter::Column.
It exists to pretend that the accessors generated by association methods
have a column type of :association, which lets us make a sensible paste
decision using PasteRole, and makes the field/attribute distinction possible
in ModelIndex.
=end
class ModelColumn
  attr_accessor :primary, :scale, :sql_type, :name, :precision, :default, :limit, :type, :meta
  
  def initialize( name, type, meta )
    @name = name
    @type = type
    @meta = meta
  end
  
  # return the underlying field name, ie "#{attribute}_id" if
  # it's an association
  def name
    @meta.name
  end
end