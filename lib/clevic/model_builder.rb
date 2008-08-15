require 'activerecord'

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

  ModelBuilder.new( Entry, table_view ) do
    # :format is optional
    plain       :date, :format => '%d-%h-%y'
    plain       :start, :format => '%H:%M'
    plain       :amount, :format => '%.2f'
    # :set is mandatory
    restricted  :vat, :label => 'VAT', :set => %w{ yes no all }, :tooltip => 'Is VAT included?'
    distinct    :description, :conditions => 'now() - date <= interval( 1 year )'
    
    # this is a read-only field
    plain       :origin, :read_only => true
    
    # for these, :format will be a dotted attribute accessor for the related
    # ActiveRecord entity, in this case an instance of Account
    relational  :debit, :format => 'name', :class_name => 'Account', :conditions => 'active = true', :order => 'lower(name)'
    relational  :credit, :format => 'name', :class_name => 'Account', :conditions => 'active = true', :order => 'lower(name)'
    
    # or like this to have an on-the-fly transform
    # item will be an instance of Account
    relational  :credit, :format => lambda {|item| item.name.downcase}, :class_name => 'Account', :conditions => 'active = true', :order => 'lower(name)', :sample => 'Leilani Member Loan'
    
    # this is a read-only display field from a related table
    # the Entry class should then define a method called currency
    # which returns an object that responds to 'short'.
    # You can also use a Proc for :display
    plain :currency, :display => 'short', :label => 'Currency'
    
    # this is a read-only display field from a related table
    # the Entry class should then define a method called currency
    # which returns an object that responds to 'currency', which
    # returns an object that responds to 'rate'.
    # You can also use a Proc for :display
    plain :some_field, :display => 'currency.rate', :label => 'Exchange Rate'
    
    # this is optional
    records :order => 'date,start'
    
    # could also be like this, where a..e are instances of Entry
    records [ a,b,c,d,e ]
  end
=end
class ModelBuilder
  
  # TODO move table_view into a UI class, one of them iterates
  # through all the fields setting delegates anyway.
  def initialize( model_class, table_view, &block )
    @model_class = model_class
    @auto_new = true
    @read_only = false
    @table_view = table_view
    @fields = []
    
    self.instance_eval( &block ) unless block.nil?
  end
  
  # The collection of visible Clevic::Field objects
  def fields
    @fields.reject{|x| !x.visible}
  end
  
  # return the index of the named field
  def index( field_name_sym )
    retval = nil
    fields.each_with_index{|x,i| retval = i if x.attribute == field_name_sym.to_sym }
    retval
  end
  
  # the ActiveRecord::Base or Clevic::Record class
  attr_reader :model_class
  
  def read_only!
    @read_only = true
  end
  
  # should this table automatically show a new blank record?
  def auto_new( bool )
    @auto_new = bool
  end
  
  def auto_new?; @auto_new; end
  
  # an ordinary field, edited in place with a text box
  def plain( attribute, options = {} )
    read_only_default( attribute, options )
    @fields << Clevic::Field.new( attribute.to_sym, model_class, options )
  end
  
  # edited with a combo box containing all previous entries in this field
  def distinct( attribute, options = {} )
    field = Clevic::Field.new( attribute.to_sym, model_class, options )
    field.delegate = DistinctDelegate.new( @table_view, attribute, model_class, options )
    @fields << field
  end

  # edited with a combo box, but restricted to a specified set
  def restricted( attribute, options = {} )
    raise "restricted must have a set" unless options.has_key?( :set )
    field = Clevic::Field.new( attribute.to_sym, model_class, options )
    field.delegate = RestrictedDelegate.new( @table_view, attribute, model_class, options )
    @fields << field
  end

  # for foreign keys. Edited with a combo box using values from the specified
  # path on the foreign key model object
  # if options[:format] has a value, it's used either as a block
  # or as a dotted path
  def relational( attribute, options = {} )
    raise ":display must be specified" if options[:display].nil?
    unless options.has_key? :class_name
      options[:class_name] = model_class.reflections[attribute].class_name || attribute.to_s.classify
    end
    field = Clevic::Field.new( attribute.to_sym, model_class, options )
    field.delegate = RelationalDelegate.new( @table_view, field.attribute_path, options )
    @fields << field
  end

  # add AR :include options for foreign keys, but it takes up too much memory,
  # and actually takes longer to load a data set
  def add_include_options
    fields.each do |field|
      if field.delegate.class == RelationalDelegate
        @options[:include] ||= []
        @options[:include] << field.attribute
      end
    end
  end

  # mostly used in the new block, but may also be
  # used as an accessor for records
  def records( *args )
    if args.size == 0
      get_records
    else
      set_records( args[0] )
    end
  end

  # This takes all the information collected
  # by the other methods, and returns the new TableModel
  def build
    # build the model with all it's collections
    # using @model here because otherwise the view's
    # reference to this very same model is garbage collected.
    @model = Clevic::TableModel.new
    @model.object_name = model_class.name
    @model.model_class = model_class
    @model.fields = @fields
    @model.read_only = @read_only
    @model.auto_new = auto_new?
    
    # the data
    @model.collection = records
    
    @model
  end
  
  # Build a default UI. All fields except the primary key are displayed
  # as editable in the table. Any belongs_to relations are used to build
  # combo boxes.
  # Try to use a sensible :display option for the related class. In order:
  # the name of the class, name, title, username
  # order by the primary key
  def default_ui
    # combine reflections and attributes into one set
    reflections = model_class.reflections.keys.map{|x| x.to_s}
    ui_columns = model_class.columns.reject{|x| x.name == model_class.primary_key }.map do |column|
      # TODO there must be a better way to do this
      att = column.name.gsub( /_id$/, '' )
      if reflections.include?( att )
        att
      else
        column.name
      end
    end
    
    # don't create an empty record, because sometimes there are
    # validations that will cause trouble
    auto_new false
    
    # build columns
    ui_columns.each do |column|
      if model_class.reflections.has_key?( column.to_sym )
        begin
          reflection = model_class.reflections[column.to_sym]
          if reflection.class == ActiveRecord::Reflection::AssociationReflection
            # try to find a sensible display class. Default to to_s
            related_class = reflection.class_name.constantize
            display_method =
            %w{#{model_class.name} name title username}.find( lambda{ 'to_s' } ) do |m|
              related_class.column_names.include?( m ) || related_class.instance_methods.include?( m )
            end
            relational column.to_sym, :display => display_method
          else
            plain column.to_sym
          end
        rescue
          puts $!.message
          puts $!.backtrace
          # just do a plain
          puts "Doing plain for #{model_class}.#{column}"
          plain column.to_sym
        end
      else
        plain column.to_sym
      end
    end
    records :order => model_class.primary_key
  end
  
  def field( attribute )
    @fields.find {|x| x.attribute == attribute }
  end
  
  # make sure this field doesn't show up
  # mainly intended to be called after default_ui has been called
  def hide( attribute )
    field( attribute ).visible = false
  end

private

  # set a sensible read-only value if it isn't already
  # specified in options doesn't alread
  def read_only_default( attribute, options )
    # sensible defaults for read-only-ness
    options[:read_only] ||= 
    case
      when options[:display].respond_to?( :call )
        # it's a Proc or a Method, so we can't set it
        true
        
      when model_class.column_names.include?( options[:display].to_s )
        # it's a DB column, so it's not read only
        false
        
      when model_class.reflections.include?( attribute )
        # one-to-one relationships can be edited. many-to-one certainly can't
        reflection = model_class.reflections[attribute]
        reflection.macro != :has_one
        
      when model_class.instance_methods.include?( attribute.to_s )
        # read-only if there's no setter for the attribute
        !model_class.instance_methods.include?( "#{attribute.to_s}=" )
      else
        # default to not read-only
        false
    end
  end

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
      @options[:auto_new] = auto_new?
      @records = CacheTable.new( model_class, @options )
    end
    @records
  end
end

end
