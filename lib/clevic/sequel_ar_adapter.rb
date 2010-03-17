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
    def count( options )
      if options.empty?
        @entity_class.dataset.count
      else
        @entity_class.dataset.filter( options ).count
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
    def count( options )
      @entity_class.count( options )
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
