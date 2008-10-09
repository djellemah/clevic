# extensions specific to clevic

require 'qtext/flags.rb'
require 'clevic/hash_collector.rb'

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

module Clevic
  # Collect row and column values in various ways
  class IndexCollector < HashCollector
    dsl_accessor :row, :column

    def initialize( row, column )
      super()
      # MUST use writers here, not instance variables
      self.row = row
      self.column = column
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
    
    # CHange and cOP(P)Y - make a new index based on this one,
    # modify the new index with values from the parameters, the
    # args hash or the block.
    # The block will instance_eval with no args, or pass self
    # if there's one arg. You can also pass two parameters, interpreted
    # as row, columns.
    # Examples:
    #   new_index = index.choppy { row 10; column 13 }
    #   new_index = index.choppy { row 10; column 13 }
    #   new_index = index.choppy( 1,3 )
    #   new_index = index.choppy { |i| i.row += 1 }
    #   new_index = index.choppy :row => 16
    #   same_index = index.choppy
    def choppy( *args, &block  )
      return ModelIndex.invalid unless self.valid?
      
      # initialize with defaults
      stash = Clevic::IndexCollector.new( row, column )
      
      case args.size
        when 0,1
          # args.first is a hash, or nil
          stash.collect( args.first, &block )
        when 2
          # args are two parameters - row, column
          stash.row, stash.column = args
          stash.collect( &block )
        else
          raise TypeError.new( "incorrect args #{args.inspect}" )
      end
      
      # return an invalid index if it's out of bounds,
      # or the choppy'd index if it's OK.
      if stash.row >= model.row_count || stash.column >= model.column_count
        ModelIndex.invalid
      else
        model.create_index( stash.row.to_i, stash.column.to_i )
      end
    end
  end

end
