require 'Qt4'
require 'ui/search_dialog_ui.rb'

class SearchDialog
  def initialize
    @layout = Ui_SearchDialog.new
    @dialog = Qt::Dialog.new
    @layout.setupUi( @dialog )
  end
  
  def exec
    @layout.search_text.set_focus
    @dialog.exec
  end
  
  def layout
    @layout
  end
  
end
