module Clevic

#includers must provide meta and display
module GenericFormat
  # Return true if the field is a date, datetime, time or timestamp.
  # If display is nil, the value is calculated, so we need
  # to check the value. Otherwise use the field metadata.
  # Cache the result for the first non-nil value.
  def is_date_time?( value )
    if value.nil?
      false
    else
      @is_date_time ||=
      if display.nil?
        [:time, :date, :datetime, :timestamp].include?( meta.type )
      else
        # it's a virtual field, so we need to use the value
        value.is_a?( Date ) || value.is_a?( Time )
      end
    end
  end
  
  # apply format to value. Use strftime for date_time types, or % for everything else.
  # If format is a proc, pass value to it.
  def do_generic_format( format, value )
    begin
      unless format.nil?
        if format.is_a? Proc
          format.call( value )
        else
          if is_date_time?( value )
            value.strftime( format )
          else
            format % value
          end
        end
      else
        value
      end
    rescue Exception => e
      puts "self: #{self.inspect}"
      puts "format: #{format.inspect}"
      puts "value.class: #{value.class.inspect}"
      puts "value: #{value.inspect}"
      puts e.message
      puts e.backtrace
      nil
    end
  end
  
end

end
