JObject = java.lang.Object
class JObject
  def const_lookup( integer )
    self.class.constants.select {|x| eval( "self.class::#{x}" ) == integer }
  end
end
