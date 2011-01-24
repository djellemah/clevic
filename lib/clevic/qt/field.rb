module Clevic

class Field
  # Convert something that responds to to_s into a Qt::Color,
  # or just return the argument if it's already a Qt::Color
  def string_or_color( s_or_c )
    case s_or_c
    when NilClass
      nil
    when Qt::Color
      s_or_c
    else
      Qt::Color.new( s_or_c.to_s )
    end
  end
end

end
