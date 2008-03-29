require 'Qt4'
require 'ui/search_dialog_ui.rb'
require 'clevic/qt_flags.rb'

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
  
  def regex?
    layout.regex.value
  end
  
  def whole_words?
    layout.whole_words.value
  end
  
  def search_combo
    layout.search_combo
  end
  
  def exec
    search_combo.set_focus
    retval = @dialog.exec
    
    # remember previous searches
    if search_combo.find_text( search_combo.current_text ) == -1
      search_combo.add_item( search_combo.current_text )
    end
    
    #~ Qt::MatchExactly	0	Performs QVariant-based matching.
    #~ Qt::MatchFixedString	8	Performs string-based matching. String-based comparisons are case-insensitive unless the MatchCaseSensitive flag is also specified.
    #~ Qt::MatchContains	1	The search term is contained in the item.
    #~ Qt::MatchStartsWith	2	The search term matches the start of the item.
    #~ Qt::MatchEndsWith	3	The search term matches the end of the item.
    #~ Qt::MatchCaseSensitive	16	The search is case sensitive.
    #~ Qt::MatchRegExp	4	Performs string-based matching using a regular expression as the search term.
    #~ Qt::MatchWildcard	5	Performs string-based matching using a string with wildcards as the search term.
    #~ Qt::MatchWrap	32	Perform a search that wraps around, so that when the search reaches the last item in the model, it begins again at the first item and continues until all items have been examined.
    
    retval
  end
  
  def search_text
    search_combo.current_text
  end
  
end
