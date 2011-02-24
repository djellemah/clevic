module Clevic

  # Provide a list of entries for a distinct field, ordered
  # by either value order, or frequency order.
  # TODO move this into the common DistinctDelegate class.
  class AttributeList
    def initialize( entity_class, attribute, attribute_value, find_options )
      @entity_class = entity_class
      @attribute, @attribute_value, @find_options = attribute, attribute_value, find_options
    end
    attr_reader :entity_class, :attribute, :attribute_value, :find_options
    
    # because Sequel::Dataset won't .filter with {}
    def conditions( dataset )
      # make sure the current attribute value is included if there's a filter
      rv = 
      if find_options.has_key?( :conditions )
        find_options[:conditions].lit | { attribute => attribute_value }
      end
      
      # filter if necessary
      unless rv.nil?
        dataset.filter( rv ) 
      else
        dataset
      end
    end
    
    # sorts by attribute
    def dataset_by_description
      # must have attribute equality test first, otherwise if find_options
      # doesn't have :conditions, then we end up with ( nil | { attribute => attribute_value } )
      # which confuses Sequel
      ds = entity_class.naked \
        .order( attribute ) \
        .select( attribute ) \
        .distinct
      conditions( ds )
    end
      
    # sorts by first letter then most frequent, instead of pure alphabetical
    def dataset_by_frequency
      ds = entity_class.naked \
        .select( attribute, :count.sql_function( attribute ) ) \
        .group( attribute ) \
        .order( :substr.sql_function( attribute,1,1 ), :count.sql_function( attribute ).desc )
      conditions( ds )
    end
    
    # by_frequency is the default
    def dataset( by_description, by_frequency )
      case
        when by_description
          dataset_by_description
        else
          dataset_by_frequency
      end
    end
  end
end
