require 'Qt4'
require 'date'

require 'andand'

require 'qtext/flags.rb'
require 'qtext/extensions.rb'

require 'clevic/extensions.rb'
require 'clevic/model_column'

module Clevic

=begin rdoc
An instance of Clevic::TableModel is constructed by Clevic::ModelBuilder from the
UI definition in a Clevic::View, or from the default Clevic::View created by
including the Clevic::Record module in a ActiveRecord::Base or Sequel::Model subclass.
=end
class TableModel < Qt::AbstractTableModel
  include QtFlags
  
  # the CacheTable of Clevic::Record or ActiveRecord::Base or Sequel::Model objects
  attr_reader :collection
  alias_method :cache_table, :collection
  
  # the collection of Clevic::Field objects
  attr_reader :fields
  
  attr_accessor :read_only
  def read_only?; read_only; end

  # should this model create a new empty record by default?
  attr_accessor :auto_new
  def auto_new?; auto_new; end
  def auto_new?; auto_new; end
  
  attr_accessor :entity_view
  attr_accessor :builder
  
  def entity_class
    entity_view.entity_class
  end
  
  signals(
    # index where error occurred, value, message
    'data_error(QModelIndex,QVariant,QString)'
  )
  
  def initialize( parent = nil )
    super
  end
  
  def fields=( arr )
    @fields = arr
    
    # reset these
    @labels = nil
    @attributes = nil
  end
  
  # field is a symbol or string referring to a column.
  # returns the index of that field.
  def field_column( field )
    fields.each_with_index {|x,i| return i if x.id == field.to_sym }
  end
  
  def field_for_index( model_index )
    fields[model_index.column]
  end
  
  def labels
    @labels ||= fields.map {|x| x.label }
  end
  
  def attributes
    @attributes ||= fields.map {|x| x.attribute }
  end
  
  def collection=( arr )
    @collection = arr
    # fill in an empty record for data entry
    if collection.size == 0 && auto_new?
      collection << entity_class.new
    end
  end
  
  def sort( col, order )
    puts 'sort'
    puts "col: #{col.inspect}"
    #~ Qt::AscendingOrder
    #~ Qt::DescendingOrder
    puts "order: #{order.inspect}"
    super
  end
  
  # this is called for read-only tables.
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
    #~ super
    []
  end
  
  # add a new item, and set defaults from the Clevic::View
  def add_new_item
    begin_insert_rows( Qt::ModelIndex.invalid, row_count, row_count )
    # set default values without triggering changed
    entity = entity_class.new
    fields.each do |f|
      unless f.default.nil?
        f.set_default_for( entity )
      end
    end
    
    collection << entity
    
    end_insert_rows
  end
  
  # rows is a collection of integers specifying row indices to remove
  def remove_rows( rows )
    # delete from the end to avoid holes affecting the indexing
    rows.uniq.sort.reverse.each do |index|
      # remove the item from the collection
      # NOTE call this within each iteration because
      # the rows array may be non-contiguous
      begin_remove_rows( Qt::ModelIndex.invalid, index, index )
      removed = collection.delete_at( index )
      end_remove_rows
      # destroy the db object, and its associated table row
      removed.destroy
    end
    
    # create a new row if auto_new is on
    add_new_item if collection.empty? && auto_new?
  end
  
  # save the AR model at the given index, if it's dirty
  def save( index )
    item = collection[index.row]
    return false if item.nil?
    if item.changed?
      if item.valid?
        retval = item.save
        emit headerDataChanged( Qt::Vertical, index.row, index.row )
        retval
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

  # Not looked up or aliased properly by Qt bindings
  def row_count
    collection.size
  end
  
  def columnCount( parent = nil )
    fields.size
  end
  
  # Not looked up or aliased properly by Qt bindings
  def column_count
    fields.size
  end
  
  def flags( model_index )
    retval = super
    
    # sometimes this actually happens. 
    # TODO probably a bug in the combo editor exit code
    return retval if model_index.column >= columnCount
    
    # TODO don't return IsEditable if the model is read-only
    if model_index.meta.type == :boolean
      retval = item_boolean_flags
    end
    
    unless model_index.field.read_only? || model_index.entity.andand.readonly? || read_only?
      retval |= qt_item_is_editable.to_i 
    end
    retval
  end
  
  def reload_data( options = nil )
    # renew cache. All records will be dropped and reloaded.
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
            labels[section]
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
        
      when qt_tooltip_role
        case orientation
          when Qt::Horizontal
            fields[section].tooltip
            
          when Qt::Vertical
            case
              when !collection[section].errors.empty?
                'Invalid data'
              when collection[section].changed?
                'Unsaved changes'
            end
        end
        
      when qt_background_role
        if orientation == Qt::Vertical
          item = collection[section]
          case
            when !item.errors.empty?
              Qt::Color.new( 'orange' )
            when item.changed?
              Qt::Color.new( 'yellow' )
          end
        end
        
      else
        #~ puts "headerData section: #{section}, role: #{const_as_string(role)}" if $options[:debug]
        nil
    end
    
    return value.to_variant
  end
  
  # Provide data to UI.
  def data( index, role = qt_display_role )
    #~ puts "data for index: #{index.inspect}, field #{index.field.attribute.inspect} and role: #{const_as_string role}"
    begin
      case role
        when qt_display_role
          # boolean values generally don't have text next to them in this context
          # check this explicitly to avoid fetching the entity from
          # the model's collection (and maybe db) when we
          # definitely don't need to
          unless index.meta.type == :boolean
            value = index.gui_value
            index.field.do_format( value ) unless value.nil?
          end
          
        when qt_edit_role
          # see comment for qt_display_role
          unless index.meta.type == :boolean
            value = index.gui_value
            index.field.do_edit_format( value ) unless value.nil?
          end
          
        when qt_checkstate_role
          if index.meta.type == :boolean
            index.gui_value ? qt_checked : qt_unchecked
          end
          
        when qt_text_alignment_role
          case index.field.alignment
            when :left; qt_alignleft
            when :right; qt_alignright
            when :centre; qt_aligncenter
            when :justified; qt_alignjustified
          end
        
        # just here to make debug output quieter
        when qt_size_hint_role;
        
        # show field with a red background if there's an error
        when qt_background_role
          index.field.background_for( index.entity ) || Qt::Color.new( 'red' ) if index.has_errors?
        
        when qt_font_role;
        
        when qt_foreground_role
          index.field.foreground_for( index.entity ) ||
          if index.field.read_only? || index.entity.andand.readonly? || read_only?
            Qt::Color.new( 'dimgray' )
          end
        
        when qt_decoration_role;
          index.field.decoration_for( index.entity )
        
        when qt_tooltip_role
          case
            # show validation errors
            when index.has_errors?
              index.errors.join("\n")
              
            # provide a tooltip when an empty relational field is encountered
            # TODO should be part of field definition
            when index.meta.type == :association
              index.field.delegate.if_empty_message
            
            # read-only field
            when index.field.read_only?
              index.field.tooltip_for( index.entity ) || 'Read-only'
              
            else
              index.field.tooltip_for( index.entity )
          end    
        else
          puts "data index: #{index}, role: #{const_as_string(role)}" if $options[:debug]
          nil
      # return the variant
      end.to_variant
        
    rescue Exception => e
      puts "#{entity_view.class.name}.#{index.field.id}: #{index.inspect} for role: #{const_as_string role} #{value.inspect} #{index.entity.inspect}"
      puts e.message
      puts e.backtrace
      nil.to_variant
    end
  end

  # data sent from UI
  # return true if conversion from variant was successful,
  # or false if something went wrong.
  def setData( index, variant, role = qt_edit_role )
    if index.valid?
      case role
      when qt_edit_role
        # Don't allow the primary key to be changed
        return false if index.attribute == entity_class.primary_key.to_sym
        
        if ( index.column < 0 || index.column >= column_count )
          raise "invalid column #{index.column}" 
        end
        
        type = index.meta.type
        value = variant.value
        #~ puts "#{type.inspect} is #{value}"
        
        # translate the value from the ui to something that
        # the AR model will understand
        begin
          index.attribute_value =
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
            when [:date,:datetime].include?( type ) && value =~ %r{^(\d{1,2})[ /-]?(\w{3})$}
              Date.parse( "#$1 #$2 #{Time.now.year.to_s}" )
            
            # if a digit only is entered, fetch month and year from
            # previous row
            when [:date,:datetime].include?( type ) && value =~ %r{^(\d{1,2})$}
              previous_entity = collection[index.row - 1]
              # year,month,day
              Date.new( previous_entity.date.year, previous_entity.date.month, $1.to_i )
            
            # this one is mostly to fix date strings that have come
            # out of the db and been formatted
            when [:date,:datetime].include?( type ) && value =~ %r{^(\d{2})[ /-](\w{3})[ /-](\d{2})$}
              Date.parse( "#$1 #$2 20#$3" )
            
            # allow lots of flexibility in entering times
            # 01:17, 0117, 117, 1 17, are all accepted
            when type == :time && value =~ %r{^(\d{1,2}).?(\d{2})$}
              Time.parse( "#$1:#$2" )
            
            # remove thousand separators, allow for space and comma
            # instead of . as a decimal separator
            when type == :decimal
              # do various transforms
              value = 
              case
                # accept a space or a comma instead of a . for floats
                when value =~ /(.*?)(\d)[ ,](\d{2})$/
                  "#$1#$2.#$3"
                else
                  value
              end
              
              # strip remaining commas
              value.gsub( ',', '' )
            
            else
              value
          end
          
          data_changed( index )
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
        if index.meta.type == :boolean
          index.entity.toggle( index.attribute )
          true
        else
          false
        end
      
      # user-defined role
      # TODO this only works with single-dotted paths
      when qt_paste_role
        if index.meta.type == :association
          field = index.field
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
  # TODO make sure the right dataset, with the right ordering
  # is passed in here
  def search( start_index, search_criteria )
    searcher = Clevic::TableSearcher.new( entity_class.dataset, search_criteria, start_index.field )
    entity = searcher.search( start_index.entity )
    
    # return matched indexes
    if entity != nil
      found_row = collection.index_for_entity( entity )
      [ create_index( found_row, start_index.column ) ]
    else
      []
    end
  end
  
  class DataChange
    class ModelIndexProxy
      attr_accessor :row
      attr_accessor :column
      
      def initialize( other = nil )
        unless other.nil?
          @row = other.row
          @column = other.column
        end
      end
    end
    
    def top_left
      @top_left ||= ModelIndexProxy.new
    end
    
    def bottom_right
      @bottom_right ||= ModelIndexProxy.new
    end
    
    attr_writer :bottom_right
    attr_writer :top_left
    
    attr_reader :index
    def index=( other )
      self.top_left = ModelIndexProxy.new( other )
      self.bottom_right = ModelIndexProxy.new( other )
    end
  end

  # A rubyish way of doing dataChanged
  # - if args has one element, it's either a single ModelIndex
  #   or something that understands top_left and bottom_right. These
  #   will be turned into a ModelIndex by calling create_index
  # - if args has two element, assume it's a two ModelIndex instances
  # - otherwise create a new DataChange and pass it to the block.
  def data_changed( *args, &block )
    case args.size
      when 1
        arg = args.first
        if ( arg.respond_to?( :top_left ) && arg.respond_to?( :bottom_right ) ) || arg.is_a?( Qt::ItemSelectionRange )
          # object is a DataChange, or a SelectionRange
          top_left_index = create_index( arg.top_left.row, arg.top_left.column )
          bottom_right_index = create_index( arg.bottom_right.row, arg.bottom_right.column )
          emit dataChanged( top_left_index, bottom_right_index )
        else
          # assume it's a ModelIndex
          emit dataChanged( arg, arg )
        end
      
      when 2
        emit dataChanged( args.first, args.last )
      
      else
        unless block.nil?
          change = DataChange.new
          block.call( change )
          # recursive call
          data_changed( change )
        end
    end
  end
  
end

end #module
