module Clevic

class Field
  # Convert a color name understood by java.awt.Color,
  # or a 0xddccee style string to a java.awt.Color
  def string_or_color( s_or_c )
    case s_or_c
    when NilClass
      nil
    when java.awt.Color
      s_or_c
    else
      color_string = s_or_c.to_s
      if java.awt.Color.constants.include?( color_string.upcase )
        eval( "java.awt.Color::#{color_string.upcase}" )
      elsif
        color_string[0..1] == "0x"
        java.awt.Color.decode( color_string )
      else
        nil
      end
    end
  end
  
  def swing_alignment
    case alignment
    when :left; javax.swing.SwingConstants::LEFT
    when :right; javax.swing.SwingConstants::RIGHT
    when :centre, :center; javax.swing.SwingConstants::CENTER
    else javax.swing.SwingConstants::LEADING
    end
  end
end

end
