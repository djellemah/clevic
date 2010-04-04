require 'sequel/model.rb'

module Clevic
  class SequelAdaptor
    def initialize( entity_class )
      @entity_class = entity_class
    end
    
    def quoted_false
      @entity_class.dataset.boolean_constant_sql( false )
    end
    
    def quoted_true
      @entity_class.dataset.boolean_constant_sql( true )
    end
    
    # options is a hash
    def count( attribute = nil, options = {} )
      dataset = @entity_class.dataset
      
      unless options.empty?
        dataset = dataset.filter( options )
      end
      
      unless attribute.nil?
        dataset = dataset.select( attribute )
      end
      
      dataset.count
    end
    
    # TODO it gets hard here. Strategy for now is to just
    # make it work, and worry about making it nice later.
    # Basically, we're translating from AR's hash options
    # to Sequel's method algebra
    def find( options )
      dataset = @entity_class.dataset
      
      if options[:limit] || options[:offset]
        dataset = dataset.limit( options[:limit], options[:offset] )
      end
      
      if options[:order]
        dataset = dataset.order( options[:order] )
      end
      
      dataset.all
    end
    
    def attribute_list( attribute, attribute_value, by_description, by_frequency, find_options, &block )
      attribute_dataset( attribute, attribute_value, by_description, by_frequency, find_options ).each( &block )
    end
    
    def attribute_dataset( attribute, attribute_value, by_description, by_frequency, find_options, &block )
      puts "find_options: #{find_options.inspect}"
      case
        when by_description
          # must have attribute equality test first, otherwise if find_options
          # doesn't have :conditions, then we end up with ( nil | { attribute => attribute_value } )
          # which confuses Sequel
          @entity_class.naked.filter( { attribute => attribute_value } | find_options[:conditions] ) \
          .order( attribute ) \
          .select( attribute ) \
          .distinct
          
        when by_frequency
          @entity_class.naked.filter
        select distinct #{attribute.to_s}, count(#{attribute.to_s})
        from #{entity_class.table_name}
        where (#{find_options[:conditions] || '1=1'})
        or #{@entity_class.connection.quote_column_name( attribute.to_s )} = #{@entity_class.connection.quote( attribute_value )}
        group by #{attribute.to_s}
        order by count(#{attribute.to_s}) desc
          
        else
          raise "not by_description not implemented"
      end
    end
  end
  
  class ActiveRecordAdaptor
    def initialize( entity_class )
      @entity_class = entity_class
    end
    
    def quoted_false
      @entity_class.connection.quoted_false
    end
    
    def quoted_true
      @entity_class.connection.quoted_true
    end
    
    # options is a hash
    def count( attribute = nil, options = {} )
      @entity_class.count( attribute, options )
    end
    
    def find( options )
      @entity_class.find( :all, options )
    end

    def query_order_description( attribute, attribute_value, find_options )
      <<-EOF
        select distinct #{attribute.to_s}, lower(#{attribute.to_s})
        from #{@entity_class.table_name}
        where (#{find_options[:conditions] || '1=1'})
        or #{@entity_class.connection.quote_column_name( attribute.to_s )} = #{@entity_class.connection.quote( attribute_value )}
        order by lower(#{attribute.to_s})
      EOF
    end
    
    def query_order_frequency( attribute, attribute_value, find_options )
      <<-EOF
        select distinct #{attribute.to_s}, count(#{attribute.to_s})
        from #{entity_class.table_name}
        where (#{find_options[:conditions] || '1=1'})
        or #{@entity_class.connection.quote_column_name( attribute.to_s )} = #{@entity_class.connection.quote( attribute_value )}
        group by #{attribute.to_s}
        order by count(#{attribute.to_s}) desc
      EOF
    end
    
    # values are passed as row objects to block
    def attribute_list( attribute, attribute_value, by_description, by_frequency, find_options, &block )
      query =
      case
        when by_description
          entity_class.adaptor.query_order_description( attribute, attribute_value, find_options )
        when by_frequency
          entity_class.adaptor.query_order_frequency( attribute, attribute_value, find_options )
        else
          entity_class.adaptor.query_order_frequency( attribute, attribute_value, find_options )
      end
        
      entity_class.connection.execute( query ).each( &block )
    end
  end
end

module ActiveRecord
  class Base
    def adaptor
      @adaptor ||= Clevic::ActiveRecordAdaptor.new( self )
    end
  end
end

module Sequel
  class Model
    class << self
      def belongs_to( *args, &block )
        many_to_one( *args, &block )
      end
      
      def has_many( *args, &block )
        one_to_many( *args, &block )
      end
      
      def table_exists?
        db.table_exists?( implicit_table_name )
      end
      
      def column_names
        columns
      end
      
      def reflections
        association_reflections 
      end
      
      def has_attribute?( attribute )
        column_names.include?( attribute )
      end
      
      def attribute_names
        columns
      end
      
      def columns_hash
        db_schema
      end
      
      # return a class containing various db methods. Not sure
      # if this is the right way to do it, but at least this way
      # the model class namespace doesn't get filled up with crud
      def adaptor
        @adaptor ||= Clevic::SequelAdaptor.new( self )
      end
    end
    
    def readonly?
      false
    end
    
    def changed?
      modified?
    end
    
    module Associations
      class ManyToOneAssociationReflection
        # return class for this side of the association
        def class_name
          self[:class_name]
        end
        
        # return class for the other side of the association
        def klass
          eval class_name
        end
      end
    end
  end
end
