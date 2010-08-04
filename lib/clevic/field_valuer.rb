module Clevic
  # to be included in something that responds to entity and field
  # used for getting values from the entity based on the definitions
  # in the field.
  module FieldValuer
  
    # the value for this index
    # used to be gui_value, but that wasn't right
    def raw_value
      field.value_for( entity )
    end
    
    def display_value
      field.do_format( raw_value ) unless raw_value.nil?
    end
    
    def edit_value
      field.do_edit_format( raw_value ) unless raw_value.nil?
    end
    
    # Set the value from an editable text representation
    # of the value
    def edit_value=( value )
      # translate the value from the ui to something that
      # the model will understand
      self.attribute_value =
      case
        # allow flexibility in entering dates. For example
        # 16jun, 16-jun, 16 jun, 16 jun 2007 would be accepted here
        # TODO need to be cleverer about which year to use
        # for when you're entering 16dec and you're in the next
        # year
        when [:date,:datetime].include?( field.meta.type ) && value =~ %r{^(\d{1,2})[ /-]?(\w{3})$}
          Date.parse( "#$1 #$2 #{Time.now.year.to_s}" )
        
        # if a digit only is entered, fetch month and year from
        # previous row
        when [:date,:datetime].include?( field.meta.type ) && value =~ %r{^(\d{1,2})$}
          previous_entity = collection[index.row - 1]
          # year,month,day
          Date.new( previous_entity.date.year, previous_entity.date.month, $1.to_i )
        
        # this one is mostly to fix date strings that have come
        # out of the db and been formatted
        when [:date,:datetime].include?( field.meta.type ) && value =~ %r{^(\d{2})[ /-](\w{3})[ /-](\d{2})$}
          Date.parse( "#$1 #$2 20#$3" )
        
        # allow lots of flexibility in entering times
        # 01:17, 0117, 117, 1 17, are all accepted
        when field.meta.type == :time && value =~ %r{^(\d{1,2}).?(\d{2})$}
          Time.parse( "#$1:#$2" )
        
        # remove thousand separators, allow for space and comma
        # instead of . as a decimal separator
        when field.meta.type == :decimal
          # do various transforms
          case
            # accept a space or a comma instead of a . for floats
            when value =~ /(.*?)(\d)[ ,](\d{2})$/
              "#$1#$2.#$3"
            else
              value
          end.gsub( ',', '' ) # strip remaining commas
        
        else
          value
      end
    end
    
    def find_related( attribute, value )
      candidates = field.related_class.adaptor.find( :all, :conditions => {attribute => value} )
      raise "too many candidates for #{value}: #{candidates.inspect}" if candidates.size != 1
      candidates.first
    end
  
    # set the field value from a value that could be
    # a text representation a-la edit_value, or possible
    # a name from a related entity
    def text_value=( value )
      case field.display
      when Symbol
        # we have a related class of some kind, 
        self.attribute_value = find_related( field.display, value )
      
      when NilClass
        self.edit_value = value
      
      when String
        # allow plain strings, but not dotted paths
        if field.display['.']
          raise "display (#{field.display}) is a dotted path"
        else
          self.attribute_value = find_related( field.display.to_sym, value )
        end
      
      else
        raise "display is a not a symbol or nil: #{display.inspect}"
      end
    end
    
    # fetch the value of the attribute, without following
    # the full path. This will return a related entity for
    # belongs_to or has_one relationships, or a plain value
    # for model attributes
    def attribute_value
      entity.send( field.attribute )
    end
    
    # cache the writer method name since it's not likely to change
    def writer
      @writer ||= "#{field.attribute.to_s}="
    end
    
    # set the value of the attribute, without following the
    # full path.
    # TODO remove need to constantly recalculate the attribute writer
    def attribute_value=( value )
      entity.send( writer, value )
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
    
  end
end
