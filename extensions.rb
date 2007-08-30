
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
  
  # Because using Qt::ModelIndex.new the whole time is wasteful
  class ModelIndex
    def self.invalid
      @@invalid ||= ModelIndex.new
    end
    
    def gui_value
      item = model.collection[row]
      attributes = model.keys[column].split( /\./ )
      attributes.inject( item ) do |value, att|
        if value.nil?
          nil
        else
          value.send( att.to_sym )
        end
      end
    end
    
    def gui_value=( obj )
      model.collection[row].send( "#{model.keys[column]}=", obj )
    end
    
    def inspect
      "Qt::ModelIndex {(#{row},#{column}) #{gui_value}}"
    end
    
    def key
      model.keys[column].to_sym
    end
    
    def metadata
      entity.column_for_attribute( key.to_sym )
    end
    
    def entity
      model.collection[row]
    end

  
  end

  # make keys easier to work with
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
      Variant.new
    end
  end
end
