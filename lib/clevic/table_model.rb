require 'date'

require 'clevic/extensions.rb'
require 'clevic/model_column'

module Clevic

=begin rdoc
An instance of Clevic::TableModel is constructed by Clevic::ModelBuilder from the
UI definition in a Clevic::View, or from the default Clevic::View created by
including the Clevic::Record module in a ActiveRecord::Base or Sequel::Model subclass.
=end
module TableModel
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
  
  # add a new item, and set defaults from the Clevic::View
  # add_new_item_start and add_new_item_end are provided by
  # the including class
  def add_new_item
    add_new_item_start
    # set default values without triggering changed
    entity = entity_class.new
    fields.each do |f|
      unless f.default.nil?
        f.set_default_for( entity )
      end
    end
    
    collection << entity
    
    add_new_item_end
  end
  
  # rows is a collection of integers specifying row indices to remove
  def remove_rows( rows )
    # delete from the end to avoid holes affecting the indexing
    rows.uniq.sort.reverse.each do |index|
      # remove the item from the collection
      # NOTE call this within each iteration because
      # the rows array may be non-contiguous
      remove_row_start( index )
      removed = collection.delete_at( index )
      remove_row_end( index )
      # destroy the db object, and its associated table row
      removed.destroy
    end
    
    # create a new row if auto_new is on
    # should really be in a signal handler
    add_new_item if collection.empty? && auto_new?
  end
  
  # save the AR model at the given index, if it's dirty
  def save( index )
    item = collection[index.row]
    return false if item.nil?
    if item.changed?
      if item.valid?
        retval = item.save
        update_vertical_header( index )
        retval
      else
        false
      end
    else
      # AR model not changed
      true
    end
  end
  
  def reload_data( options = nil )
    # renew cache. All records will be dropped and reloaded.
    self.collection = self.cache_table.renew( options )
    # tell the UI we had a major data change
    reset
  end

  # return a collection of indexes that match the search criteria
  # at the moment this only returns the first index found
  # TODO could handle dataset creation better
  def search( start_index, search_criteria )
    ordered_dataset = entity_class.dataset.order( *cache_table.order_attributes.map{|oa| oa.attribute.to_sym.send( oa.direction ) } )
    searcher = Clevic::TableSearcher.new(
      ordered_dataset,
      search_criteria,
      start_index.field
    )
    entity = searcher.search( start_index.entity )
    
    # return matched indexes
    if entity != nil
      found_row = collection.index_for_entity( entity )
      [ create_index( found_row, start_index.column ) ]
    else
      []
    end
  end
  
  # TODO still think this should be in Field, becaues it's not specific
  # to table-style views
  def translate_to_db_object( table_index, value )
    type = table_index.meta.type
    # translate the value from the ui to something that
    # the AR model will understand
    case
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

end

end #module
