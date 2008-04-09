=begin rdoc
  The Qt bindings look up constants for each call. This module
  caches the constant values. Most of these are called for each
  cell in a table, so caching them gives us a good performance
  increase.
=end
module QtFlags
  def item_boolean_flags
    @item_boolean_flags ||= Qt::ItemIsEnabled | Qt::ItemIsSelectable | Qt::ItemIsUserCheckable
  end
  
  def qt_item_is_editable
    @qt_item_is_editable ||= Qt::ItemIsEditable
  end
  
  def qt_display_role
    @qt_display_role ||= Qt::DisplayRole
  end
  
  def qt_edit_role
    @qt_edit_role ||= Qt::EditRole
  end
  
  def qt_paste_role
    @qt_paste_role ||= Qt::PasteRole
  end
  
  def qt_checkstate_role
    @qt_checkstate_role ||= Qt::CheckStateRole
  end
  
  def qt_text_alignment_role
    @qt_text_alignment_role ||= Qt::TextAlignmentRole
  end
  
  def qt_size_hint_role
    @qt_size_hint_role ||= Qt::SizeHintRole
  end
  
  def qt_checked
    @qt_checked ||= Qt::Checked
  end
  
  def qt_unchecked
    @qt_unchecked ||= Qt::Unchecked
  end
  
  def qt_alignright
    @qt_alignright ||= Qt::AlignRight
  end
  
  def qt_aligncenter
    @qt_aligncenter ||= Qt::AlignCenter
  end
  
  def qt_decoration_role
    @qt_decoration_role ||= Qt::DecorationRole
  end
  
  def qt_background_role
    @qt_background_role ||= Qt::BackgroundRole
  end
  
  def qt_font_role
    @qt_font_role ||= Qt::FontRole
  end
  
  def qt_foreground_role
    @qt_foreground_role ||= Qt::ForegroundRole
  end
  
  def const_as_string( constant )
    case constant
      when qt_text_alignment_role; 'Qt::TextAlignmentRole'
      when qt_checkstate_role; 'Qt::CheckStateRole'
      when qt_edit_role; 'Qt:EditRole'
      when qt_display_role; 'Qt::DisplayRole'
      when Qt::ToolTipRole; 'Qt::ToolTipRole'
      when Qt::StatusTipRole; 'Qt::StatusTipRole'
      when Qt::DecorationRole; 'Qt::DecorationRole'
      when Qt::BackgroundRole; 'Qt::BackgroundRole'
      when Qt::FontRole; 'Qt::FontRole'
      when Qt::ForegroundRole; 'Qt::ForegroundRole'
      when Qt::TextColorRole; 'Qt::TextColorRole'
      
      else "#{constant} unknown"
    end
  end
end
