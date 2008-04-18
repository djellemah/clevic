require 'clevic/table_model.rb'
require 'clevic/delegates.rb'
require 'clevic/cache_table.rb'
require 'clevic/field.rb'

module Clevic

=begin rdoc
This is used to define a set of fields in a UI, any related tables,
restrictions on data entry, formatting and that kind of thing.

Optional specifiers are:
* :sample is used to size the columns. Will default to some hopefully sensible value from the db.
* :format is something that can be understood by strftime (for time and date
  fields) or understood by % (for everything else)
* :alignment is one of Qt::TextAlignmentRole, ie Qt::AlignRight, Qt::AlignLeft, Qt::AlignCenter
* :set is the set of strings that are accepted by a RestrictedDelegate

In the case of relational fields, all other options are passed to ActiveRecord::Base#find

For example, a the UI for a model called Entry would be defined like this:

  Clevic::TableView.new( Entry, parent ).create_model do
    # :format is optional
    plain       :date, :format => '%d-%h-%y'
    plain       :start, :format => '%H:%M'
    plain       :amount, :format => '%.2f'
    # :set is mandatory
    restricted  :vat, :label => 'VAT', :set => %w{ yes no all }, :tooltip => 'Is VAT included?'
    distinct    :description, :conditions => 'now() - date <= interval( 1 year )'
    relational  :debit, 'name', :class_name => 'Account', :conditions => 'active = true', :order => 'lower(name)'
    relational  :credit, 'name', :class_name => 'Account', :conditions => 'active = true', :order => 'lower(name)'
    
    # this is optional
    records :order => 'date,start'
    
    # could also be like this, where a..e are instances of Entry
    records [ a,b,c,d,e ]
  end
=end
class ModelBuilder
  # The collection of Clevic::Field objects
  attr_reader :fields
  
  def initialize( table_view )
    @table_view = table_view
    @fields = []
  end
  
  # return the index of the named field
  def index( field_name_sym )
    retval = nil
    fields.each_with_index{|x,i| retval = i if x.attribute == field_name_sym.to_sym }
    retval
  end
  
  # the AR class for this table
  def model_class
    @table_view.model_class
  end

  # an ordinary field, edited in place with a text box
  def plain( attribute, options = {} )
    @fields << Clevic::Field.new( attribute.to_sym, model_class, options )
  end
  
  # edited with a combo box containing all previous entries in this field
  def distinct( attribute, options = {} )
    field = Clevic::Field.new( attribute.to_sym, model_class, options )
    field.delegate = DistinctDelegate.new( @table_view, attribute, @table_view.model_class, options )
    @fields << field
  end

  # edited with a combo box, but restricted to a specified set
  def restricted( attribute, options = {} )
    raise "restricted must have a set" unless options.has_key?( :set )
    field = Clevic::Field.new( attribute.to_sym, model_class, options )
    field.delegate = RestrictedDelegate.new( @table_view, attribute, @table_view.model_class, options )
    @fields << field
  end

  # for foreign keys. Edited with a combo box using values from the specified
  # path on the foreign key model object
  def relational( attribute, path, options = {} )
    field = Clevic::Field.new( attribute.to_sym, model_class, options )
    field.path = path
    field.delegate = RelationalDelegate.new( @table_view, field.attribute_path, options )
    @fields << field
  end

  # add AR :include options for foreign keys, but it takes up too much memory,
  # and actually takes longer to load a data set
  def add_include_options
    @fields.each do |field|
      if field.delegate.class == RelationalDelegate
        @options[:include] ||= []
        @options[:include] << field.attribute
      end
    end
  end

  # mostly used in the create_model block, but may also be
  # used as an accessor for records
  def records( *args )
    if args.size == 0
      get_records
    else
      set_records( args[0] )
    end
  end

  # This is intended to be called from the view class which instantiated
  # this builder object.
  def build
    # build the model with all it's collections
    # using @model here because otherwise the view's
    # reference to this very same model is mysteriously
    # set to nil
    @model = Clevic::TableModel.new( self )
    @model.object_name = @table_view.model_class.name
    @model.dots = @fields.map {|x| x.column }
    @model.labels = @fields.map {|x| x.label }
    @model.attributes = @fields.map {|x| x.attribute }
    @model.attribute_paths = @fields.map { |x| x.attribute_path }
    
    # the data
    @model.collection = records
    # fill in an empty record
    @model.collection << model_class.new if @model.collection.size == 0
    
    # now set delegates
    @table_view.item_delegate = Clevic::ItemDelegate.new( @table_view )
    @fields.each_with_index do |field, index|
      @table_view.set_item_delegate_for_column( index, field.delegate )
    end
    
    # give the built model back to the view class
    # see above comment about @model
    @table_view.model = @model
  end

private

  # The collection of model objects to display in a table
  # arg can either be a Hash, in which case a new CacheTable
  # is created, or it can be an array
  # called by records( *args )
  def set_records( arg )
    if arg.class == Hash
      # need to defer this until all fields are collected
      @options = arg
    else
      @records = arg
    end
  end

  # return a collection of records. Usually this will be a CacheTable.
  # called by records( *args )
  def get_records
    if @records.nil?
      #~ add_include_options
      @records = CacheTable.new( model_class, @options )
    end
    @records
  end
end

end