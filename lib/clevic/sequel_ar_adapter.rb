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
      
      def columns_hash
        db_schema
      end
    end
  end
end
