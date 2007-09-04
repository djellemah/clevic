=begin
This table model allows an ActiveRecord or ActiveResource to be used as a
basis for a Qt::AbstractTableModel for viewing in a Qt::TableView.

Initially written by Richard Dale and Silvio Fonseca. Extensively modified
by John Anderson.

=end

require 'Qt4'
require 'date'
require 'extensions.rb'

=begin
  labels are the headings in the table view
  
  columns are the dotted attribute paths that specify how to get values from
  the underlying ActiveRecord model
  
  attribute_paths is the collection of columns, each split into components by .
  
  attributes are the first-level of the columns
  
  collection is the set of model objects
  
=end
class EntryTableModel < Qt::AbstractTableModel
  
  attr_accessor :collection, :columns, :attributes, :attribute_paths, :labels

  # the index where the error occurred, the incoming value, and the error message
  signals 'data_error(QModelIndex, QVariant, QString)'

  def initialize( collection = nil, columns = nil )
    super()
    @metadatas = []
    
    if collection.class == EntryBuilder
      @builder = collection
    elsif collection
      @collection = collection
      if columns
        if columns.kind_of? Hash
          @columns = columns.keys
          @labels = columns.values
        else
          @columns = columns
        end
      else
        @columns = build_columns([], @collection.first.attributes)
      end
      @labels ||= @columns.collect { |k| k.split( /\./ )[0].humanize }
      @attributes = @columns.collect { |k| k.split( /\./ )[0].to_sym }
      @attribute_paths = @columns.collect { |k| k.split( /\./ ) }
    end
  end
  
  def build_columns( columns, attrs, prefix="" )
    attrs.inject( columns ) do |cols, a|
      if a[1].respond_to? :attributes
        build_keys(cols, a[1].attributes, prefix + a[0] + ".")
      else
        cols << prefix + a[0]
      end
    end
  end
  
  # cache metadata (ActiveRecord#column_for_attribute) because it't not going
  # to change over the lifetime of the table
  def metadata( column )
    @metadatas[column] ||= collection[0].column_for_attribute( attributes[column] )
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
    item = collection[index.row]
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
  
  def rowCount( parent = nil )
    collection.size
  end

  def row_count
    collection.size
  end
  
  def columnCount( parent = nil )
    columns.size
  end
  
  def column_count
    columns.size
  end
  
  def flags( model_index )
    retval = Qt::ItemIsEditable | super( model_index )
    if model_index.metadata.type == :boolean
      retval = Qt::ItemIsEnabled | Qt::ItemIsSelectable | Qt::ItemIsUserCheckable
    end
    retval
  end

  # cache these because the qt binding does them slowly
  def qt_display_role
    @qt_display_role ||= Qt::DisplayRole
  end
  
  def qt_edit_role
    @qt_edit_role ||= Qt::EditRole
  end
  
  def qt_checkstate_role
    @qt_checkstate_role ||= Qt::CheckStateRole
  end
  
  def qt_text_alignment_role
    @qt_text_alignment_role ||= Qt::TextAlignmentRole
  end
  
  # values for horizontal and vertical headers
  def headerData( section, orientation, role )
    value = 
    case role
      when qt_display_role
        case orientation
          when Qt::Horizontal
            @labels[section]
          when Qt::Vertical
            collection[section].id
        end
        
      when qt_text_alignment_role
        case orientation
          when Qt::Vertical
            Qt::AlignRight | Qt::AlignVCenter
        end
        
    end
      
    return value.to_variant
  end

  # send data to UI
  def data( index, role = qt_display_role )
    begin
      return Qt::Variant.invalid if index.entity.nil?
      
      value = nil
      case
        when role == qt_display_role || role == qt_edit_role
          # boolean values generally don't have text next to them in this context
          return nil.to_variant if index.metadata.type == :boolean
          
          field_name = index.attribute_path
          value = index.gui_value
          # TODO formatting doesn't really belong here
          if value != nil
            value = value.strftime '%H:%M' if field_name == 'start' || field_name == 'end'
            value = value.strftime( '%d-%h-%y' ) if field_name == 'date'
            value = "%.2f" % value if field_name == 'amount'
          end
          
        when role == qt_checkstate_role
          if index.metadata.type == :boolean
            value = ( index.gui_value ? Qt::Checked : Qt::Unchecked )
          end
          
        when role == qt_text_alignment_role
          value = 
          case index.metadata.type
            when :decimal
              Qt::AlignRight
            when :integer
              Qt::AlignRight
            when :boolean
              Qt::AlignCenter
          end
      end
      
      value.to_variant
    rescue Exception => e
      puts e.backtrace.join( "\n" )
      puts "#{index.inspect} #{value.inspect} #{index.entity.inspect} #{e.message}"
      nil.to_variant
    end
  end

  # data set from UI
  def setData( index, variant, role = Qt::EditRole )
    if index.valid?
      case role
      when Qt::EditRole
        # Don't allow the primary key to be changed
        return false if index.attribute == :id
        
        if ( index.column < 0 || index.column >= columns.size )
          raise "invalid column #{index.column}" 
        end
        
        type = index.metadata.type
        value = variant.value
        
        # modify some data
        begin
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
            when type == :date && value =~ %r{^(\d{1,2})[ /-]?(\w{3})$}
              value = Date.parse( "#$1 #$2 #{Time.now.year.to_s}" )
            
            # if a digit only is entered, fetch month and year from
            # previous row
            when type == :date && value =~ %r{^(\d{1,2})$}
              previous_entity = collection[index.row - 1]
              # year,month,day
              value = Date.new( previous_entity.date.year, previous_entity.date.month, $1.to_i )
            
            # this one is mostly to fix date strings that have come
            # out of the db and been formatted
            when type == :date && value =~ %r{^(\d{2})[ /-](\w{3})[ /-](\d{2})$}
              value = Date.parse( "#$1 #$2 20#$3" )
            
            # allow lots of flexibility in entering times
            # 01:17, 0117, 117, 1 17, are all accepted
            when type == :time && value =~ %r{^(\d{1,2}).?(\d{2})$}
              value = Time.parse( "#$1:#$2" )
          end
          
          index.gui_value = value
          emit dataChanged( index, index )
          true
        rescue Exception => e
          puts e.backtrace.join( "\n" )
          emit data_error( index, variant, e.message )
          false
        end
        
      when Qt::CheckStateRole
        if index.metadata.type == :boolean
          index.entity.toggle!( index.attribute )
        end
        true
        
      else
        puts "role: #{role.inspect}"
        true
        
      end
    else
      false
    end
  end
end
