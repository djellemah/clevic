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
end
