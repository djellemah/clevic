# extensions specific to clevic

class Object
  # recursively calls each entry in path_ary
  # will return nil if any entry in path_ary
  # results in a nil value.
  def evaluate_path( path_ary )
    path_ary.inject( self ) do |value, att|
      value.nil? ? nil : value.send( att )
    end
  end

  # pass self to the block and return the results of the block.
  def with( &block )
    yield( self )
  end

  # return a list of the subclasses of a class
  # from Matt Williams
  # http://matthewkwilliams.com/index.php/2008/08/22/rubys-objectspace-subclasses/
  def self.subclasses(direct = false)
    classes = []
    if direct
      ObjectSpace.each_object(Class) do |c|
        next unless c.superclass == self
        classes << c
      end
    else
      ObjectSpace.each_object(Class) do |c|
        next unless c.ancestors.include?(self) and (c != self)
        classes << c
      end
    end
    classes
  end
end

class String
  # just grab the character code of the last character in the string
  # TODO this won't work in unicode or utf-8
  def to_char
    if RUBY_VERSION <= '1.8.6'
      self[0]
    else
      bytes.first
    end
  end
end

class Array
  def sparse_hash
    Hash[ *(first..last).map do |index|
      [index, include?( index ) ]
    end.flatten ]
  end

  def sparse
    (first..last).map do |index|
      index if include?( index )
    end
  end

  def section
    return [] if empty?
    rv = [first]
    self[1..-1].each_with_index do |next_value, index|
      break if rv.last.succ != next_value
      rv << next_value
    end
    rv
  end

  # group by ascending values
  def group
    parts = []
    next_section = section
    if next_section.empty?
      parts
    else
      parts << section
      parts + self[section.size..-1].group
    end
  end

  def range
    first..last
  end
end

def Range
  def distance
    last - first
  end
end

begin
  Date.new.freeze.to_s
rescue TypeError
  # Workaround for the date freeze issue, if it exists.
  class Date
    def freeze
      self
    end
  end
end
