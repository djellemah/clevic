require 'sequel'
require 'clevic/model_column.rb'

module Sequel
  module Plugins
    module Meta
      # plugin :meta calls this.
      # model is the model class. The rest is whatever options are
      # in the plugin call
      #  plugin :meta
      def self.configure(model, options = {})
        model.instance_eval do
          # store model-related stuff here
        end
      end
      
      module ClassMethods
        # Copy the necessary class instance variables to the subclass.
        def inherited(subclass)
          super
          #~ store = @cache_store
          #~ ttl = @cache_ttl
          #~ cache_ignore_exceptions = @cache_ignore_exceptions
          #~ subclass.instance_eval do
            #~ @cache_store = store
            #~ @cache_ttl = ttl
            #~ @cache_ignore_exceptions = cache_ignore_exceptions
          #~ end
        end
        
        def meta
          if @meta.nil?
            @meta = {}
            db_schema.each do |key,value|
              @meta[key] = ModelColumn.new( key, value.merge( :association => false ) )
            end
            
            association_reflections.each do |key,value|
              @meta[key] = ModelColumn.new( key, value.merge( :association => true ) )
            end
          end
          @meta
        end
        
        # reload from current metadata
        def meta!
          @meta = nil
          meta
        end
        
        # column and relations, but not keys for defined relations
        def attributes
          meta.reject do |column,model_column|
            meta.values.map( &:keys ).include?( [ column ] )
          end
        end
      end
      
      module InstanceMethods
      end
    end
  end
end

Sequel::Model.plugin :meta
