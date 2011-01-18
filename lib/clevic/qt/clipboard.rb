module Clevic

  # see swing clipboard if you need a stream with io/like

  # Clevic wrapper for Qt::Application::clipboard
  class Clipboard
    def text=( value )
      Qt::Application::clipboard.text = value
    end
    
    def text
      Qt::Application::clipboard.text
    end
  end

end
