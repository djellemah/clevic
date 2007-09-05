require 'entry_table_model.rb'
require 'delegates.rb'

class EntryField
  attr_accessor :attribute, :path, :sample, :format, :label, :delegate, :class_name
  
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
  
class EntryBuilder
  attr_reader :fields
  
  def initialize( entry_table_view )
    @entry_table_view = entry_table_view
    @fields = []
    @active_record_options = [ :conditions, :class_name, :order ]
  end

  def plain( attribute, options = {} )
    @fields << EntryField.new( attribute.to_sym, options )
  end
  
  def distinct( attribute, options = {} )
    field = EntryField.new( attribute.to_sym, options )
    field.delegate = DistinctDelegate.new( @entry_table_view, attribute, @entry_table_view.model_class, collect_finder_options( options ) )
    @fields << field
  end

  def relational( attribute, path, options = {} )
    field = EntryField.new( attribute.to_sym, options )
    field.path = path
    field.delegate = RelationalDelegate.new( @entry_table_view, field.attribute_path, options )
    @fields << field
  end
  
  def collection=( ary )
    @collection = ary
  end

  # intended to be called from the view class which instantiated
  # this builder object
  def build
    # build the model with all it's collections
    model = EntryTableModel.new( self )
    model.dots = @fields.map {|x| x.column }
    model.labels = @fields.map {|x| x.label }
    model.attributes = @fields.map {|x| x.attribute }
    model.attribute_paths = @fields.map { |x| x.attribute_path }
    
    # the data
    model.collection = @collection
    
    # now set delegates
    @fields.each_with_index do |field, index|
      @entry_table_view.set_item_delegate_for_column( index, field.delegate )
    end
    
    @entry_table_view.model = model
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
