require 'sequel/model.rb'
require 'clevic/ar_methods.rb'
require 'clevic/attribute_list.rb'

module Clevic
  class SequelAdaptor
    def initialize( entity_class )
      @entity_class = entity_class
      # TODO rename to ar_methods
      @entity_class.plugin :ar_methods
    end
    
    def quoted_false
      @entity_class.dataset.boolean_constant_sql( false )
    end
    
    def quoted_true
      @entity_class.dataset.boolean_constant_sql( true )
    end
    
    def count( *args )
      @entity_class.count_ar( *args )
    end
    
    def find( *args )
      @entity_class.find_ar( *args )
    end
    
    def attribute_list( attribute, attribute_value, by_description, by_frequency, find_options, &block )
      lister = AttributeList.new( @entity_class, attribute, attribute_value, find_options )
      ds = lister.dataset( by_description, by_frequency )
      ds.each( &block )
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
      def translate_options( options )
        options[:key] = options[:foreign_key].andand.to_sym
        options.delete( :foreign_key )
        
        options[:class] = options[:class_name].andand.to_sym
        options.delete( :class_name )
        options
      end
      
      def belongs_to( name, options, &block )
        many_to_one( name, translate_options( options ), &block )
      end
      
      def has_many( name, options, &block )
        one_to_many( name, translate_options( options ), &block )
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
    
    def new_record?; new?; end
    
    class Errors
      def invalid?( field_name )
        self.has_key?( field_name )
      end
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
