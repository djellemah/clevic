# extensions specific to clevic

require 'qtext/flags.rb'
require 'qtext/hash_collector.rb'

module ActiveRecord
  class Base
    # recursively calls each entry in path_ary
    def evaluate_path( path_ary )
      path_ary.inject( self ) do |value, att|
        if value.nil?
          nil
        else
          value.send( att )
        end
      end
    end
    
    # checks to see if attribute_sym is either in the column
    # name list, or in the set of reflections.
    def self.has_attribute?( attribute_sym )
      if column_names.include?(  attribute_sym.to_s )
        true
      elsif reflections.has_key?(  attribute_sym )
        true
      else
        false
      end
    end
    
    def self.attribute_names
      ( column_names + reflections.keys.map {|sym| sym.to_s} ).sort
    end
  end
end

# convenience methods
module Qt

  PasteRole = UserRole + 1
  
  class ItemDelegate
    # overridden in EntryDelegate subclasses
    def full_edit
    end
  end
  
  # This provides a bunch of methods to get easy access to the entity
  # and it's values directly from the index without having to keep
  # asking the model and jumping through other unncessary hoops
  class ModelIndex
    # the value to be displayed in the gui for this index
    def gui_value
      field.value_for( entity )
    end
    
    # return the Clevic::Field for this index
    def field
      @field ||= model.field_for_index( self )
    end
    
    def dump
      if valid?
      <<-EOF
      field: #{field_name} => #{field_value}
      attribute: #{attribute.inspect} => #{attribute_value.inspect}
      metadata: #{metadata.inspect}
      EOF
      else
        'invalid'
      end
    end
    
    # return the attribute of the underlying entity corresponding
    # to the column of this index
    def attribute
      model.attributes[column]
    end
    
    # fetch the value of the attribute, without following
    # the full path. This will return a related entity for
    # belongs_to or has_one relationships, or a plain value
    # for model attributes
    def attribute_value
      entity.send( attribute )
    end
    
    # set the value of the attribute, without following the
    # full path.
    # TODO remove need to constantly recalculate the attribute writer
    def attribute_value=( obj )
      entity.send( "#{attribute.to_s}=", obj )
    end
    
    # returns the ActiveRecord column_for_attribute
    def metadata
      # use the optimised version
      model.metadata( column )
    end
    
    # return the table's field name. For associations, this would
    # be suffixed with _id
    def field_name
      metadata.name
    end
    
    # return the value of the field, it may be the _id value
    def field_value
      entity.send( field_name )
    end
    
    # the underlying entity
    def entity
      return nil if model.nil?
      @entity ||= model.collection[row]
    end
    
    attr_writer :entity
    
    # return true if validation failed for this indexes field
    def has_errors?
      # virtual fields don't have metadata
      if metadata.nil?
        false
      else
        entity.errors.invalid?( field_name.to_sym )
      end
    end
    
    # return a collection of errors. Unlike AR, this
    # will always return an array that will have zero, one
    # or many elements.
    def errors
      [ entity.errors[field_name.to_sym] ].flatten
    end
    
  end

end
