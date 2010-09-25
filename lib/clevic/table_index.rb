require 'clevic/field_valuer.rb'

module Clevic
  # to be included in something that responds to model, row, column
  module TableIndex
    include FieldValuer
    
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
    
    def prev
      choppy( :row => row - 1 )
    end
    
    # return the attribute of the underlying entity corresponding
    # to the column of this index
    def attribute
      model.attributes[column]
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
    
    # sort by row, then column
    def <=>( other )
      row_comp = self.row <=> other.row
      if row_comp == 0
        self.column <=> other.column
      else
        row_comp
      end
    end
    
    def inspect
      "#<TableIndex (#{row},#{column}) '#{raw_value rescue "no raw value: #{$!.message}"}'>"
    end
    
    # return a string (row,column)
    # suitable for displaying to users, ie 1-based not 0-based
    def rc
      "(#{row+1},#{column+1})"
    end
  end
end
