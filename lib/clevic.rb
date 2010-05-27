# This provides enough to define UIs.

require 'clevic/model_column.rb'

module Clevic
  def self.base_entity_class
    Sequel::Model
  end
  
  # define a method called meta on a Sequel::Model
  # class so that we can get to the metadata
  def self.define_meta( entity_class )
    method_body = lambda do
      if @meta.nil?
        @meta = {}
        db_schema.merge( association_reflections ).each do |key,value|
          @meta[key] = ModelColumn.new( key, value )
        end
      end
      @meta
    end
    
    entity_class.class.send( :define_method, :meta, &method_body )
  end
end

require 'clevic/sequel_ar_adapter.rb'
require 'clevic/db_options.rb'
require 'clevic/record.rb'
require 'clevic/view.rb'
