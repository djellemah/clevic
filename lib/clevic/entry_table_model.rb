=begin
This table model allows an ActiveRecord or ActiveResource to be used as a
basis for a Qt::AbstractTableModel for viewing in a Qt::TableView.

Initial idea by Richard Dale and Silvio Fonseca.
=end

require 'Qt4'
require 'date'
require 'clevic/extensions'
require 'clevic/model_column'

=begin rdoc
* labels are the headings in the table view

* dots are the dotted attribute paths that specify how to get values from
  the underlying ActiveRecord model

* attribute_paths is a collection of attribute symbols. It comes from
  dots, and is split on /\./

* attributes are the first-level of the dots

* collection is the set of ActiveRecord model objects (also called entities)
=end
class EntryTableModel < Qt::AbstractTableModel
  
  attr_accessor :collection, :dots, :attributes, :attribute_paths, :labels

  # the index where the error occurred, the incoming value, and the error message
  signals(
    # index where error occurred, value, message
    'data_error(QModelIndex,QVariant,QString)',
    # top_left, bottom_right
    'dataChanged(constQModelIndex&,constQModelIndex&)'
  )
  
  def initialize( builder )
    super()
    @metadatas = []
    @builder = builder
  end
  
  def hasIndex( row, col, parent )
    puts 'hasIndex'
    puts "row: #{row.inspect}"
    puts "col: #{col.inspect}"
    puts "parent: #{parent.inspect}"
    super
  end
  
  def hasChildren( *args )
    puts 'hasChildren'
    puts "args: #{args.inspect}"
    super
  end
  
  def sort( col, order )
    puts 'sort'
    puts "col: #{col.inspect}"
    #~ Qt::AscendingOrder
    #~ Qt::DescendingOrder
    puts "order: #{order.inspect}"
    super
  end
  
  def match( start_index, role, search_value, hits, match_flags )
    puts "#{__FILE__}:#{__LINE__}"
    puts start_index.dump
    puts "search_value: #{search_value.inspect}"
    puts "role: #{role.inspect}"
    results = model_class.find( :all, :conditions => "#{start_index.attribute} ilike '%#{search_value}%'" )
    puts "results: #{results.inspect}"
    
    #~ Qt::MatchExactly	0	Performs QVariant-based matching.
    #~ Qt::MatchFixedString	8	Performs string-based matching. String-based comparisons are case-insensitive unless the MatchCaseSensitive flag is also specified.
    #~ Qt::MatchContains	1	The search term is contained in the item.
    #~ Qt::MatchStartsWith	2	The search term matches the start of the item.
    #~ Qt::MatchEndsWith	3	The search term matches the end of the item.
    #~ Qt::MatchCaseSensitive	16	The search is case sensitive.
    #~ Qt::MatchRegExp	4	Performs string-based matching using a regular expression as the search term.
    #~ Qt::MatchWildcard	5	Performs string-based matching using a string with wildcards as the search term.
    #~ Qt::MatchWrap	32	Perform a search that wraps around, so that when the search reaches the last item in the model, it begins again at the first item and continues until all items have been examined.
    super
  end
  
  def submit
    puts "submit"
    super
  end
  
  def build_dots( dots, attrs, prefix="" )
    attrs.inject( dots ) do |cols, a|
      if a[1].respond_to? :attributes
        build_keys(cols, a[1].attributes, prefix + a[0] + ".")
      else
        cols << prefix + a[0]
      end
    end
  end
  
  def model_class
    @builder.model_class
  end
  
  # cache metadata (ActiveRecord#column_for_attribute) because it't not going
  # to change over the lifetime of the table
  # if the column is an attribute, create a ModelColumn
  def metadata( column )
    if @metadatas[column].nil?
      meta = collection[0].column_for_attribute( attributes[column] )
      if meta.nil?
        meta = collection[0].column_for_attribute( "#{attributes[column]}_id".to_sym )
        if meta.nil?
          return nil
        else
          @metadatas[column] = ModelColumn.new( attributes[column], :association, meta )
        end
      else
        @metadatas[column] = meta
      end
    end
    @metadatas[column]
  end
  
  def add_new_item
    # 1 new row
    begin_insert_rows( Qt::ModelIndex.invalid, row_count, row_count )
    collection << model_class.new
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
    return false if item.nil?
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
    dots.size
  end
  
  def column_count
    dots.size
  end
  
  def flags( model_index )
    # TODO don't return IsEditable if the model is read-only
    retval = Qt::ItemIsEditable | super( model_index )
    if model_index.metadata.type == :boolean
      retval = Qt::ItemIsEnabled | Qt::ItemIsSelectable | Qt::ItemIsUserCheckable
    end
    retval
  end
  
  def fetchMore( parent )
    #~ puts "fetchMore"
    #~ reload_data if canFetchMore( parent )
  end
  
  def canFetchMore( parent )
    false
    #~ puts "canFetchMore"
    #~ puts "self.collection.size: #{self.collection.size.inspect}"
    #~ puts "self.collection.sql_count: #{self.collection.sql_count.inspect}"
    # Here, test for self.collection.size - new_records != self.collection.sql_count
    # maintaining new_records will be the tricky part
    #~ result = self.collection.size != self.collection.sql_count
    #~ puts "result: #{result.inspect}"
    #~ result
  end

  def reload_data( options = {} )
    # renew cache
    self.collection = self.collection.renew( options )
    # tell the UI we had a major data change
    reset
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
  
  def qt_size_hint_role
    @qt_size_hint_role ||= Qt::SizeHintRole
  end
  
  def const_as_string( constant )
    case constant
      when qt_text_alignment_role; 'Qt::TextAlignmentRole'
      when qt_checkstate_role; 'Qt::CheckStateRole'
      when qt_edit_role; 'Qt:EditRole'
      when qt_display_role; 'Qt::DisplayRole'
      when Qt::DecorationRole; 'Qt::DecorationRole'
      when Qt::ToolTipRole; 'Qt::ToolTipRole'
      when Qt::StatusTipRole; 'Qt::StatusTipRole'
      when Qt::DecorationRole; 'Qt::DecorationRole'
      when Qt::BackgroundRole; 'Qt::BackgroundRole'
      when Qt::FontRole; 'Qt::FontRole'
      when Qt::ForegroundRole; 'Qt::ForegroundRole'
      when Qt::TextColorRole; 'Qt::TextColorRole'
      
      else "#{constant} unknown"
    end
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
            # don't force a fetch from the db
            if collection.cached_at?( section )
              collection[section].id
            else
              section
            end
        end
        
      when qt_text_alignment_role
        case orientation
          when Qt::Vertical
            Qt::AlignRight | Qt::AlignVCenter
        end
          
      when Qt::SizeHintRole
        # anything other than nil here makes the headers disappear.
        nil
          
      else
        #~ puts "headerData section: #{section}, role: #{const_as_string(role)}" if $options[:debug]
        nil
    end
    
    return value.to_variant
  end

  # Send data to UI. Default formatting is done here.
  def data( index, role = qt_display_role )
    begin
      return Qt::Variant.invalid if index.entity.nil?
      
      value =
      case
        when role == qt_display_role || role == qt_edit_role
          # boolean values generally don't have text next to them in this context
          return nil.to_variant if index.metadata.type == :boolean
          value = index.gui_value rescue nil
          # TODO formatting doesn't really belong here
          if value != nil
            field = @builder.fields[index.column]
            if field.format
              value = 
              case index.metadata.type
                when :time; value.strftime( field.format )
                when :date; value.strftime( field.format )
                else; field.format % value
              end
            else
              value = 
              case index.metadata.type
                when :time; value.strftime( '%H:%M' )
                when :date; value.strftime( '%d-%h-%y' )
                when :decimal; "%.2f" % value
                when :float; "%.2f" % value
                else; value
              end
            end
          end
          
        when role == qt_checkstate_role
          if index.metadata.type == :boolean
            index.gui_value ? Qt::Checked : Qt::Unchecked
          end
          
        when role == qt_text_alignment_role
          field = @builder.fields[index.column]
          field.alignment ||
            case index.metadata.type
              when :decimal; Qt::AlignRight
              when :integer; Qt::AlignRight
              when :float; Qt::AlignRight
              when :boolean; Qt::AlignCenter
            end
          
        when qt_size_hint_role
          nil
            
        else
          puts "data section: #{section}, role: #{const_as_string(role)}" if $options[:debug]
          nil
      end
      
      value.to_variant
    rescue Exception => e
      puts e.backtrace.join( "\n" )
      puts "#{index.inspect} #{value.inspect} #{index.entity.inspect} #{e.message}"
      nil.to_variant
    end
  end

  # data sent from UI
  def setData( index, variant, role = Qt::EditRole )
    if index.valid?
      case role
      when Qt::EditRole
        # Don't allow the primary key to be changed
        return false if index.attribute == :id
        
        if ( index.column < 0 || index.column >= dots.size )
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
          puts e.message
          emit data_error( index, variant, e.message )
          false
        end
        
      when Qt::CheckStateRole
        if index.metadata.type == :boolean
          index.entity.toggle!( index.attribute )
        end
        true
      
      # user-defined role
      # TODO this only works with single-dotted paths
      when Qt::PasteRole
        if index.metadata.type == :association
          field = @builder.fields[index.column]
          association_class = field.class_name.constantize
          candidates = association_class.find( :all, :conditions => [ "#{field.attribute_path[1]} = ?", variant.value ] )
          case candidates.size
            when 0; puts "No match for #{variant.value}"
            when 1; index.attribute_value = candidates[0]
            else; puts "Too many for #{variant.value}"
          end
        else
          index.attribute_value = variant.value
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
