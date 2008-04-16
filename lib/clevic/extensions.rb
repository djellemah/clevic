# need this here otherwise the definition of BigDecimal#to_variant
# causes and error
require 'bigdecimal'
require 'clevic/qt_flags.rb'

# Because Qt::Variant.new( obj ) is a PITA to type
class Object
  def to_variant
    begin
      unless frozen?
        @variant ||= Qt::Variant.new( self )
      else
        Qt::Variant.new( self )
      end
    rescue Exception => e
      puts e.backtrace.join( "\n" )
      puts "error converting #{self.inspect} to variant: #{e.message}"
      nil.to_variant
    end
  end
end

class Date
  def to_variant
    self.to_s.to_variant
  end
end

class BigDecimal
  def to_variant
    self.to_f.to_variant
  end
end

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
  
  class Base
    # use the cursor constant for the application override cursor
    # while the block is executing.
    # Return the value of the block
    def override_cursor( cursor_constant, &block )
      Qt::Application.setOverrideCursor( Qt::Cursor.new( cursor_constant ) )
      retval = yield
      Qt::Application.restoreOverrideCursor
      retval
    end
  end

  class CheckBox
    include QtFlags
    def value
      checkState == qt_checked
    end
    
    def value=( obj )
      # This seems backwards to me, but it works
      setCheckState( ( obj == false ? Qt::Unchecked : Qt::Checked ) )
    end
  end
  
  class Enum
    def to_variant
      to_i.to_variant
    end
  end
  
  class ItemDelegate
    # overridden in EntryDelegate subclasses
    def full_edit
    end
  end
  
  class ItemSelection
    include Enumerable
    
    def each( &block )
      index = 0
      max = self.count
      while index < max
        yield( self.at( index ) )
        index += 1
      end
    end
    
    def size
      self.count
    end
    
  end
  
  class ItemSelectionRange 
    def single_cell?
      self.top == self.bottom && self.left == self.right
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
      return nil if entity.nil?
      entity.evaluate_path( attribute_path )
    end
    
    # set the value returned from the gui, as whatever the underlying
    # entity wants it to be
    # TODO this will break for more than 2 objects in a path
    def gui_value=( obj )
      entity.send( "#{model.dots[column]}=", obj )
    end
    
    alias_method :old_inspect, :inspect
    def inspect
      #<Qt::ModelIndex:0xb6004e8c>
      # fetch address from superclass inspect
      super =~ /ModelIndex:(.*)>/
      # format nicely
      #~ "#<Qt::ModelIndex:#{$1} xy=(#{row},#{column}) gui_value=#{gui_value}>"
      "#<Qt::ModelIndex:#{$1} xy=(#{row},#{column})>"
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
    
    # sort by row, then column
    def <=>( other )
      row_comp = self.row <=> other.row
      if row_comp == 0
        self.column <=> other.column
      else
        row_comp
      end
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
  
  class Rect
    alias_method :old_inspect, :inspect
    def inspect
      "#<Qt::Rect x=#{self.x} y=#{self.y} w=#{self.width} h=#{self.height}>"
    end
  end
  
  class Region
    def inspect
      "#<Qt::Region bounding_rect=#{self.bounding_rect.inspect}>"
    end
  end
  
  class TabWidget
    include Enumerable
    def each_tab( &block )
      save_index = self.current_index
      (0...self.count).each do |i|
        yield( self.widget(i) )
      end
    end
    alias_method :each, :each_tab
  end
  
  class Variant
    # return an empty variant
    def self.invalid
      @@invalid ||= Variant.new
    end
    
    # because the qtruby inspect doesn't provide the value
    alias_method :old_inspect, :inspect
    def inspect
      "#<Qt::Variant value=#{self.value} typeName=#{self.typeName}>"
    end
    
    # return the string of the value of this variant
    def to_s
      self.value.to_s
    end
  end
  
end
