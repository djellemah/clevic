module Clevic

class ModelBuilder
  # Not sure if this is the right place to put it, but
  # try here and see if it works out.
  def plain_delegate( field )
    if field.meta.type == :boolean
      BooleanDelegate.new( field )
    else
      TextDelegate.new( field )
    end
  end
end

end
