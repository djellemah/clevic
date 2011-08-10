module Qt
  # Implement the methods needed for ComboBox to work with the
  # various Clevic::Delegate classes.
  class ComboBox
    def no_insert=( bool )
      self.insert_policy = Qt::ComboBox::NoInsert if bool
    end

    def <<( item )
      text, data = item_to_editor( item )
      add_item( text, data.to_variant )
    end

    def include?( item )
      text, data = item_to_editor( item )
      find_data( data.to_variant ) != -1
    end

    def selected_item=( item )
      text, data = item_to_editor( item )
      self.current_index = find_data( data.to_variant )
    end

    def selected_item
      delegate.editor_to_item( item_data( self.current_index ).value )
    end

    # wrapper for the delegate method so we don't have
    # to keep checking for nil values
    def item_to_editor( item )
      if item
        delegate.item_to_editor( item )
      else
        ['', nil ]
      end
    end

    # wrapper for the delegate method so we don't have
    # to keep checking for nil values
    def editor_to_item( data )
      if data
        delegate.editor_to_item( data )
      else
        nil
      end
    end
  end

  # Adding these to Qt::Widget as the superclass
  # doesn't work for some reason.
  class ComboBox
    attr_accessor :delegate
  end

  class LineEdit
    attr_accessor :delegate
  end
end
