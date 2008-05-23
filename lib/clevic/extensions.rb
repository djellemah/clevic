# extensions specific to clevic

require 'clevic/qt_flags.rb'

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
      return nil if entity.nil?
      entity.evaluate_path( attribute_path )
    end
    
    # set the value returned from the gui, as whatever the underlying
    # entity wants it to be
    # TODO this will break for more than 2 objects in a path
    def gui_value=( obj )
      entity.send( "#{model.dots[column]}=", obj )
    end
    
    def dump
      <<-EOF
      field_name: #{field_name}
      field_value: #{field_value}
      dotted_path: #{dotted_path.inspect}
      attribute_path: #{attribute_path.inspect}
      attribute: #{attribute.inspect}
      attribute_value: #{attribute_value.inspect}
      metadata: #{metadata.inspect}
      EOF
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
    # full path
    def attribute_value=( obj )
      entity.send( "#{attribute.to_s}=", obj )
    end
    
    # the dotted attribute path, same as a 'column' in the model
    def dotted_path
      model.dots[column]
    end
    
    # return an array of path elements from dotted_path
    def attribute_path
      return nil if model.nil?
      model.attribute_paths[column]
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
    
    # return the value of the field, it the _id value
    def field_value
      entity.send( field_name )
    end
    
    # the underlying entity
    def entity
      return nil if model.nil?
      #~ puts "fetching entity from collection for xy=(#{row},#{column})" if @entity.nil?
      @entity ||= model.collection[row]
    end
    
    attr_writer :entity
    
  end

end
