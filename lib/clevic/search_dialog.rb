require 'Qt4'
require 'clevic/ui/search_dialog_ui.rb'
require 'qtext/flags.rb'

module Clevic

  class SearchDialog
    include QtFlags
    attr_reader :match_flags, :layout
    
    def initialize
      @layout = Ui_SearchDialog.new
      @dialog = Qt::Dialog.new
      @layout.setupUi( @dialog )
    end
    
    def from_start?
      layout.from_start.value
    end
    
    def from_start=( value )
      layout.from_start.value = value
    end
    
    def regex?
      layout.regex.value
    end
    
    def whole_words?
      layout.whole_words.value
    end
    
    def search_combo
      layout.search_combo
    end
    
    def forwards?
      layout.forwards.checked?
    end
    
    def backwards?
      layout.backwards.checked?
    end
    
    # return either :backwards or :forwards
    def direction
      return :forwards if forwards?
      return :backwards if backwards?
      raise "direction not known"
    end
    
    def exec( text = '' )
      search_combo.edit_text = text.to_s
      search_combo.set_focus
      retval = @dialog.exec
      
      # remember previous searches
      if search_combo.find_text( search_combo.current_text ) == -1
        search_combo.add_item( search_combo.current_text )
      end
      
      retval
    end
    
    def search_text
      search_combo.current_text
    end
    
  end

end
