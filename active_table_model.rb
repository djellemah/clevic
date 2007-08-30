=begin
This table model allows an ActiveRecord or ActiveResource to be used as a
basis for a Qt::AbstractTableModel for viewing in a Qt::TableView. Example
usage:

app = Qt::Application.new(ARGV)
agencies = TravelAgency.find(:all, :conditions => [:name => 'Another Agency'])
model = ActiveTableModel.new(agencies)
table = Qt::TableView.new
table.model = model
table.show
app.exec

Written by Richard Dale and Silvio Fonseca

=end

require 'Qt4'
require 'date'
require 'extensions.rb'

class ActiveTableModel < Qt::AbstractTableModel
  attr_accessor :collection, :keys
  
  def initialize(collection, columns=nil)
    super()
    @collection = collection
    if columns
      if columns.kind_of? Hash
        @keys = columns.keys
        @labels = columns.values
      else
        @keys = columns
      end
    else
      @keys = build_keys([], @collection.first.attributes)
    end
    @labels ||= @keys.collect { |k| k.split( /\./ )[0].humanize }
  end
  
  def build_keys(keys, attrs, prefix="")
    attrs.inject(keys) do |cols, a|
      if a[1].respond_to? :attributes
        build_keys(cols, a[1].attributes, prefix + a[0] + ".")
      else
        cols << prefix + a[0]
      end
    end
  end
  
    def value_for_key( item, field_name )
      # is it a plain value or a relation?
      field_path = field_name.split( /\./ )
      
      # recursively find the display value
      value = item
      field_path.each do |node|
        new_value = value.send( node.to_sym )
        if new_value.nil? && field_path.size > 1
          break
        end
        value = new_value
      end

      value
    end

  def column_for_key( key )
    @keys.each_with_index do |obj,i|
      if obj.split( /\./ ).include?( key.to_s )
        return i
      end
    end
    raise "index not found for #{key.inspect}"
  end
  
  def attribute_for_key( key )
    @keys.each do |obj|
      pieces = obj.split( /\./ )
      if pieces.include?( key.to_s )
        return pieces[1..-1].join('.')
      end
    end
    raise "attribute not found for #{key.inspect}"
  end
  
  def add_new_item
    # 1 new row
    begin_insert_rows( Qt::ModelIndex.invalid, row_count, row_count )
    collection << collection[0].class.new
    end_insert_rows
  end
  
  # rows is a collection of integers specifying row indices to remove
  def remove_rows( rows )
    # delete from the end to avoid holes affecting the indexing
    rows.sort.reverse.each do |index|
      # remove the item from the collection
      begin_remove_rows( Qt::ModelIndex.invalid, index, index )
      removed = collection.delete_at( index )
      end_remove_rows
      # destroy the db object, and its table row
      removed.destroy
    end
  end
  
  def save( index )
    item = @collection[index.row]
    if item.changed?
      if item.valid?
        item.save
      else
        false
      end
    else
      true
    end
  end
  
  # return the first part of a possible dotted key name
  def first_key( index )
    key = keys[index]
    key.split( /\./ )[0]
  end
  
  def rowCount( parent = nil )
    @collection.size
  end

  def row_count
    collection.size
  end
  
  def columnCount( parent = nil )
    @keys.size
  end
  
  def column_count
    @keys.size
  end
  
  def headerData( section, orientation, role = Qt::DisplayRole )
    invalid = Qt::Variant.new
    return invalid unless role == Qt::DisplayRole
    v = case orientation
      when Qt::Horizontal
        @labels[section]
      when Qt::Vertical
        @collection[section].id
      else
        raise "unknown orientation: #{orientation}"
    end
    return v.to_variant
  end

  def flags( model_index )
    retval = Qt::ItemIsEditable | super( model_index )
    if model_index.metadata.type == :boolean
      #~ retval = Qt::ItemIsEditable | Qt::ItemIsEnabled | Qt::ItemIsSelectable | Qt::ItemIsUserCheckable
      retval = Qt::ItemIsEnabled | Qt::ItemIsSelectable | Qt::ItemIsUserCheckable
    end
    retval
  end

  # send data to UI
  def data( index, role = Qt::DisplayRole )
    item = @collection[index.row]
    return Qt::Variant.invalid if item.nil?

    case
    when role == Qt::CheckStateRole
      if index.metadata.type == :boolean
        return ( index.gui_value ? Qt::Checked : Qt::Unchecked ).to_variant
      end
      
    when role == Qt::DisplayRole || role == Qt::EditRole
      raise "invalid column #{index.column}" if ( index.column < 0 || index.column >= @keys.size )
      return nil.to_variant if index.metadata.type == :boolean
      
      field_name = keys[index.column].to_s
      value = value_for_key( item, field_name )

      # default to the id for relations
      # but don't set id for plain attributes
      if value.class.ancestors.include?( ActiveRecord::Base ) && field_name.include?( '.' )
        value = value.id
      end

      # TODO formatting doesn't really belong here
      if value != nil
        value = value.strftime '%H:%M' if field_name == 'start' || field_name == 'end'
        value = value.strftime '%d-%h-%y' if value != nil && field_name == 'date'
      end
    else
      value = nil
    end
  
    return value.to_variant
  end

  # send data to model
  def setData( index, variant, role = Qt::EditRole )
    if index.valid?
      case role
      when Qt::EditRole
        att = keys[index.column]
        # Don't allow the primary key to be changed
        if att == 'id'
          return false
        end

        item = @collection[index.row]
        if (index.column < 0 || index.column >= @keys.size)
          raise "invalid column #{index.column}" 
        end
        
        type = item.column_for_attribute( att.to_sym ).type
        value = variant.value
        
        # modify some data
        case
        when value.class.name == 'Qt::Date'
          value = Date.new( value.year, value.month, value.day )
          
        when value.class.name == 'Qt::Time'
          value = Time.new( value.hour, value.min, value.sec )
          
        # allow flexibility in entering dates. For example
        # 16jun, 16-jun, 16 jun, 16 jun 2007 would be accepted here
        # TODO need to be cleverer about which year to use
        # for when you're entering 16dec and you're in the next
        # year
        when type == :date && value =~ %r{^(\d{2})[ /-]?(\w{3})$}
          value = Date.parse( "#$1 #$2 #{Time.now.year.to_s}" )
        
        # this one is mostly to fix date strings that have come
        # out of the db and been formatted
        when type == :date && value =~ %r{^(\d{2})[ /-](\w{3})[ /-](\d{2})$}
          value = Date.parse( "#$1 #$2 20#$3" )
        
        # allow lots of flexibility in entering times
        # 01:17, 0117, 117, 1 17, are all accepted
        when type == :time && value =~ %r{^(\d{1,2}).?(\d{2})$}
          value = Time.parse( "#$1:#$2" )
          
        end
        
        cmd = "item[:%s] = value" % att.to_s.gsub(/\./, "'].attributes['")
        eval( cmd )
        emit dataChanged( index, index )
        return true
      when Qt::CheckStateRole
        if index.metadata.type == :boolean
          index.entity.toggle!( index.key.to_sym )
        end
        
      else
        puts "role: #{role.inspect}"
      end
    else
      return false
    end
  end
end
