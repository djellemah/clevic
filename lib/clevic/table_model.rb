require 'Qt4'
require 'date'
require 'clevic/extensions'
require 'clevic/model_column'
require 'clevic/qt_flags.rb'
require 'pp'

module Clevic

=begin rdoc
This table model allows an ActiveRecord or ActiveResource to be used as a
basis for a Qt::AbstractTableModel for viewing in a Qt::TableView.

Initial idea by Richard Dale and Silvio Fonseca.

* labels are the headings in the table view

* dots are the dotted attribute paths that specify how to get values from
  the underlying ActiveRecord model

* attribute_paths is a collection of attribute symbols. It comes from
  dots, and is split on /\./

* attributes are the first-level of the dots

* collection is the set of ActiveRecord model objects (also called entities)
=end
class TableModel < Qt::AbstractTableModel
  include QtFlags
  
  attr_accessor :collection, :dots, :attributes, :attribute_paths, :labels

  signals(
    # index where error occurred, value, message
    'data_error(QModelIndex,QVariant,QString)',
    # top_left, bottom_right
    'dataChanged(const QModelIndex&,const QModelIndex&)'
  )
  
  def initialize( builder )
    super()
    @metadatas = []
    @builder = builder
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
  # TODO use ActiveRecord::Base.reflections instead
  def metadata( column )
    if @metadatas[column].nil?
      meta = model_class.columns_hash[attributes[column].to_s]
      if meta.nil?
        meta = model_class.columns_hash[ "#{attributes[column]}_id" ]
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
  # TODO call begin_remove and end_remove around the whole block
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
  
  # save the AR model at the given index, if it's dirty
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
      # AR model not changed
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
    retval = qt_item_is_editable | super( model_index )
    if model_index.metadata.type == :boolean
      retval = item_boolean_flags
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
  
  # Provide data to UI.
  def data( index, role = qt_display_role )
    #~ puts "data for index: #{index.inspect} and role: #{const_as_string role}"
    begin
      retval =
      case role
        when qt_display_role, qt_edit_role
          # boolean values generally don't have text next to them in this context
          # check explicitly to avoid fetching the entity from
          # the model's collection when we don't need to
          unless index.metadata.type == :boolean
            begin
              value = index.gui_value
              unless value.nil?
                field = @builder.fields[index.column]
                field.do_format( value )
              end
            rescue Exception => e
              puts e.backtrace
            end
          end
          
        when qt_checkstate_role
          if index.metadata.type == :boolean
            index.gui_value ? qt_checked : qt_unchecked
          end
          
        when qt_text_alignment_role
          field = @builder.fields[index.column]
          field.alignment

        # these are just here to make debug output quieter
        when qt_size_hint_role;
        when qt_background_role;
        when qt_font_role;
        when qt_foreground_role;
        when qt_decoration_role;
        when qt_tooltip_role;

        else
          puts "data index: #{index}, role: #{const_as_string(role)}" if $options[:debug]
          nil
      end
      
      # return a variant
      retval.to_variant
    rescue Exception => e
      puts e.backtrace.join( "\n" )
      puts "#{index.inspect} #{value.inspect} #{index.entity.inspect} #{e.message}"
      nil.to_variant
    end
  end

  # data sent from UI
  def setData( index, variant, role = qt_edit_role )
    if index.valid?
      case role
      when qt_edit_role
        # Don't allow the primary key to be changed
        return false if index.attribute == :id
        
        if ( index.column < 0 || index.column >= dots.size )
          raise "invalid column #{index.column}" 
        end
        
        type = index.metadata.type
        value = variant.value
        
        # translate the value from the ui to something that
        # the AR model will understand
        begin
          index.gui_value =
          case
            when value.class.name == 'Qt::Date'
              Date.new( value.year, value.month, value.day )
              
            when value.class.name == 'Qt::Time'
              Time.new( value.hour, value.min, value.sec )
              
            # allow flexibility in entering dates. For example
            # 16jun, 16-jun, 16 jun, 16 jun 2007 would be accepted here
            # TODO need to be cleverer about which year to use
            # for when you're entering 16dec and you're in the next
            # year
            when type == :date && value =~ %r{^(\d{1,2})[ /-]?(\w{3})$}
              Date.parse( "#$1 #$2 #{Time.now.year.to_s}" )
            
            # if a digit only is entered, fetch month and year from
            # previous row
            when type == :date && value =~ %r{^(\d{1,2})$}
              previous_entity = collection[index.row - 1]
              # year,month,day
              Date.new( previous_entity.date.year, previous_entity.date.month, $1.to_i )
            
            # this one is mostly to fix date strings that have come
            # out of the db and been formatted
            when type == :date && value =~ %r{^(\d{2})[ /-](\w{3})[ /-](\d{2})$}
              Date.parse( "#$1 #$2 20#$3" )
            
            # allow lots of flexibility in entering times
            # 01:17, 0117, 117, 1 17, are all accepted
            when type == :time && value =~ %r{^(\d{1,2}).?(\d{2})$}
              Time.parse( "#$1:#$2" )
              
            else
              value
          end
          
          emit dataChanged( index, index )
          # value conversion was successful
          true
        rescue Exception => e
          puts e.backtrace.join( "\n" )
          puts e.message
          emit data_error( index, variant, e.message )
          # value conversion was not successful
          false
        end
        
      when qt_checkstate_role
        if index.metadata.type == :boolean
          index.entity.toggle!( index.attribute )
          true
        else
          false
        end
      
      # user-defined role
      # TODO this only works with single-dotted paths
      when qt_paste_role
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
  
  # return a set of indexes that match the search criteria
  def search( start_index, search_criteria )
    # get the search value parameter, in SQL format
    search_value =
    if search_criteria.whole_words?
      "% #{search_criteria.search_text} %"
    else
      "%#{search_criteria.search_text}%"
    end

    # build up the conditions
    bits = collection.build_sql_find( start_index.entity, search_criteria.direction )
    conditions = "#{model_class.connection.quote_column_name( start_index.field_name )} ilike :search_value"
    conditions += ( " and " + bits[:sql] ) unless search_criteria.from_start?
    params = { :search_value => search_value }
    params.merge!( bits[:params] ) unless search_criteria.from_start?
    #~ puts "conditions: #{conditions.inspect}"
    #~ puts "params: #{params.inspect}"
    # find the first match
    entity = model_class.find(
      :first,
      :conditions => [ conditions, params ],
      :order => search_criteria.direction == :forwards ? collection.order : collection.reverse_order
    )
    
    # return matched indexes
    if entity != nil
      found_row = collection.index_for_entity( entity )
      [ create_index( found_row, start_index.column ) ]
    else
      []
    end
  end
  
end

end #module
