
# Because Qt::Variant.new( obj ) is a PITA to type
class Object
  def to_variant
    return Qt::Variant.new( self )
  end
end

# convenience methods
module Qt

  # Because using Qt::ModelIndex.new the whole time is wasteful
  class ModelIndex
    def self.invalid
      @@invalid ||= ModelIndex.new
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
end
