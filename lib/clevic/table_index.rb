module Clevic
  # to be included in something that responds to model, row, column
  # TODO implement choppy
  module TableIndex
    # the value for this index
    # used to be gui_value, but that wasn't right
    def raw_value
      @raw_value ||= field.value_for( entity )
    end
    
    def display_value
      field.do_format( raw_value ) unless raw_value.nil?
    end
    
    def edit_value
      field.do_edit_format( raw_value ) unless raw_value.nil?
    end
    
    def tooltip
      case
        # show validation errors
        when has_errors?
          errors.join("\n")
          
        # provide a tooltip when an empty relational field is encountered
        # TODO should be part of field definition
        when meta.type == :association
          field.delegate.if_empty_message
        
        # read-only field
        when field.read_only?
          field.tooltip_for( entity ) || 'Read-only'
          
        else
          field.tooltip_for( entity )
      end
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
      meta: #{meta.inspect}
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
    
    # returns the list of ModelColumn metadata
    def meta
      # use the optimised version
      # TODO just use the model version instead?
      field.meta
    end
    
    # return the table's field name. For associations, this would
    # be suffixed with _id
    def field_name
      meta.name
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
      if meta.nil?
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
