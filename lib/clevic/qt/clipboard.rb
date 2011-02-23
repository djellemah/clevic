module Clevic

  # see swing clipboard if you need a stream with io/like

  # Clevic wrapper for Qt::Application::clipboard
  class Clipboard
    def system
      Qt::Application::clipboard
    end
    
    def text=( value )
      system.text = value
    end
    
    def text
      system.text
    end
    
    def text?
      system.mime_data.has_text
    end
    
    def html?
      system.mime_data.has_html
    end
    
    # TODO figure out why Qt never has anything other than text.
    # Could be because the event loop isn't running when testing
    # from irb.
    def html
      system.mime_data.html
    end
  end

end
