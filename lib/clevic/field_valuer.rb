module Clevic
  # to be included in something that responds to entity and field
  # used for getting values from the field and the entity
  module FieldValuer
  
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
    
    def attribute_value
      field.attribute_value_for( entity )
    end
    
    def tooltip
      case
        # show validation errors
        when has_errors?
          errors.join("\n")
          
        # provide a tooltip when an empty relational field is encountered
        # TODO should be part of field definition
        when field.meta.type == :association
          field.delegate.if_empty_message
        
        # read-only field
        when field.read_only?
          field.tooltip_for( entity ) || 'Read-only'
          
        else
          field.tooltip_for( entity )
      end
    end
    # fetch the value of the attribute, without following
    # the full path. This will return a related entity for
    # belongs_to or has_one relationships, or a plain value
    # for model attributes
    def attribute_value
      field.attribute_value_for( entity )
    end
    
    # set the value of the attribute, without following the
    # full path.
    # TODO remove need to constantly recalculate the attribute writer
    def attribute_value=( obj )
      entity.send( "#{attribute.to_s}=", obj )
    end
    
  end
end
