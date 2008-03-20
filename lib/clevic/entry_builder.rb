require 'entry_table_model.rb'
require 'delegates.rb'

class EntryField
  attr_accessor :attribute, :path, :sample, :format, :label, :delegate, :class_name, :alignment
  
  def initialize( attribute, options )
    @attribute = attribute
    options.each do |key,value|
      self.send( "#{key}=", value ) if respond_to?( key )
    end
  end

  def label
    @label ||= attribute.to_s.humanize
  end
  
  def column
    [attribute.to_s, path].compact.join('.')
  end
  
  # return an array of the various attribute parts
  def attribute_path
    pieces = [ attribute.to_s ]
    pieces.concat( path.split( /\./ ) ) unless path.nil?
    pieces.map{|x| x.to_sym}
  end
  
end

=begin
  This is similar to the Rails migrations usage.
  
  :sample is used to size the columns
  
    EntryTableView.new( Entry, parent ).create_model do |builder|
      builder.plain       :date, :format => '%d-%h-%y'
      builder.plain       :start, :format => '%H:%M'
      builder.plain       :amount, :format => '%.2f'
      builder.restricted  :vat, :label => 'VAT', :set => %w{ yes no all }
      builder.distinct    :description, :conditions => 'now() - date <= interval( 1 year )'
      builder.relational  :debit, 'name', :class_name => 'Account', :conditions => 'active = true', :order => 'lower(name)'
      builder.relational  :credit, 'name', :class_name => 'Account', :conditions => 'active = true', :order => 'lower(name)'
    end
=end
class EntryBuilder
  attr_reader :fields
  
  def initialize( entry_table_view )
    @entry_table_view = entry_table_view
    @fields = []
    @active_record_options = [ :conditions, :class_name, :order ]
  end
  
  # return the index of the named field
  def index( field_name_sym )
    retval = nil
    fields.each_with_index{|x,i| retval = i if x.attribute == field_name_sym.to_sym }
    retval
  end

  # an ordinary field, edited in place with a text box
  def plain( attribute, options = {} )
    @fields << EntryField.new( attribute.to_sym, options )
  end
  
  # edited with a combo box containing all previous entries in this field
  def distinct( attribute, options = {} )
    field = EntryField.new( attribute.to_sym, options )
    field.delegate = DistinctDelegate.new( @entry_table_view, attribute, @entry_table_view.model_class, collect_finder_options( options ) )
    @fields << field
  end

  # edited with a combo box, but restricted to a specified set
  def restricted( attribute, options = {} )
    raise "restricted must have a set" unless options.has_key?( :set )
    field = EntryField.new( attribute.to_sym, options )
    field.delegate = RestrictedDelegate.new( @entry_table_view, attribute, @entry_table_view.model_class, collect_finder_options( options ) )
    @fields << field
  end

  # for foreign keys. Edited with a combo box using values from the specified
  # path on the foreign key model object
  def relational( attribute, path, options = {} )
    field = EntryField.new( attribute.to_sym, options )
    field.path = path
    field.delegate = RelationalDelegate.new( @entry_table_view, field.attribute_path, options )
    @fields << field
  end

  # The collection of model objects to display in a table
  def collection=( ary )
    @collection = ary
  end

  # intended to be called from the view class which instantiated
  # this builder object
  def build
    # build the model with all it's collections
    # using @model here because otherwise the view's
    # reference to this very same model is mysteriously
    # set to nil
    @model = EntryTableModel.new( self )
    @model.object_name = @entry_table_view.model_class.name
    @model.dots = @fields.map {|x| x.column }
    @model.labels = @fields.map {|x| x.label }
    @model.attributes = @fields.map {|x| x.attribute }
    @model.attribute_paths = @fields.map { |x| x.attribute_path }
    
    # the data
    @model.collection = @collection
    
    # now set delegates
    @fields.each_with_index do |field, index|
      @entry_table_view.set_item_delegate_for_column( index, field.delegate )
    end
    
    # give the built model back to the view class
    # see above comment about @model
    @entry_table_view.model = @model
  end
  
protected
  def collect_finder_options( options )
    new_options = {}
    options.each do |key,value|
      if @active_record_options.include?( key )
        new_options[key] = value
      end
    end
  end
    
  def remove_finder_options( options )
    new_options = {}
    options.each do |key,value|
      if !@active_record_options.include?( key )
        new_options[key] = value
      end
    end
  end

end
