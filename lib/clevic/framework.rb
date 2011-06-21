=begin rdoc
  To handle multiple GUI frameworks, Clevic makes use of 
  Ruby's open classes. Whenever there is a class that
  interacts with a GUI framework (say Qt, or Java Swing)
  the framework-specific part of the class is loaded
  first to get access to the framework's inheritance
  hierarchy, then the file with the framework-neutral
  code is loaded. The code below helps to check
  that the relevant methods from framework-neutral code
  are already defined by the time the framework-neutral
  class definition is executed.
=end

class Class
  
  # method_name can be a symbol or a string.
  # 
  # If a method of this name doesn't already exist
  # add it, so that if when it's called later it raises
  # and exception. Otherwise if the named method already
  # exists, just leave it alone.
  def framework_responsibility( method_name )
    unless method_defined?( method_name.to_sym )
      define_method method_name do
        raise "Framework-specific code not defined for #{self.class}##{method_name}"
      end
    end
  end
  
  def subclass_responsibility( method_name )
    unless instance_methods.include?( method_name.to_s )
      define_method( method_name ) do
        raise "#{method_name} is subclass responsibility for #{self.class}"
      end
    end
  end
  
end
