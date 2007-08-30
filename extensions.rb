
# Because Qt::Variant.new( obj ) is a PITA to type
class Object
  def to_variant
    return Qt::Variant.new( self )
  end
end

# convenience methods
module Qt

  class CheckBox
    def value
      checkState == Qt::Checked
    end
    
    def value=( obj )
      # This seems backwards to me, but it works
      setCheckState( ( obj ? Qt::Unchecked : Qt::Checked ) )
    end
  end
  
  class Enum
    def to_variant
      to_i.to_variant
    end
  end
  
  # This provides a bunch of methods to get easy access to the entity
  # and it's values directly from the index without having to keep
  # asking the model and jumping through other unncessary hoops
  class ModelIndex
    
    # Because using Qt::ModelIndex.new the whole time is wasteful
    def self.invalid
      @@invalid ||= ModelIndex.new
    end
    
    # the value to be displayed in the gui for this index
    def gui_value
      item = model.collection[row]
      attributes = model.columns[column].split( /\./ )
      attributes.inject( item ) do |value, att|
        if value.nil?
          nil
        else
          value.send( att.to_sym )
        end
      end
    end
    
    # set the value returned from the gui, as whatever the underlying
    # entity wants it to be
    def gui_value=( obj )
      model.collection[row].send( "#{model.columns[column]}=", obj )
    end
    
    def inspect
      "Qt::ModelIndex {(#{row},#{column}) #{gui_value}}"
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
    def attribute_path
      model.columns[column]
    end
    
    # the ActiveRecord column_for_attribute
    def metadata
      entity.column_for_attribute( attribute )
    end
    
    # the underlying entity
    def entity
      model.collection[row]
    end
    
  end

  # make keystrokes easier to work with
  class KeyEvent
    # override otherwise the new method_missing fails
    # to call the old_method_missing
    def modifiers
      old_method_missing( :modifiers )
    end
    
    # override otherwise the new method_missing fails
    # to call the old_method_missing
    def key
      old_method_missing( :key )
    end

    # override otherwise the new method_missing fails
    # to call the old_method_missing
    def text
      old_method_missing( :text )
    end

    # is the control key pressed?
    def ctrl?
      modifiers & Qt::ControlModifier.to_i == Qt::ControlModifier.to_i
    end
    
    alias_method :old_method_missing, :method_missing
    
    # shortcut for the Qt::Key_Whatever constants
    # just say event.whatever?
    def method_missing( sym, *args )
      begin
        if sym.to_s[-1] == "?"[0]
          key?( sym.to_s[0..-2] )
        else
          old_method_missing( sym, args )
        end
      rescue Exception => e
        old_method_missing( sym, args )
      end
    end
    
    def key?( name )
      key == eval( "Qt::Key_#{name.to_s.camelize}" )
    end
    
  end
  
  class Variant
    def self.invalid
      @@invalid ||= Variant.new
    end
  end
end
