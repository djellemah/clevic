require 'set'

require 'qtext/flags.rb'
require 'clevic/table_index.rb'

# convenience methods
module Qt
  PasteRole = UserRole + 1 unless defined?( PasteRole )
  
  class AbstractItemDelegate
    # overridden in EntryDelegate subclasses
    def full_edit
    end
  end
  
  # This provides a bunch of methods to get easy access to the entity
  # and it's values directly from the index without having to keep
  # asking the model and jumping through other unncessary hoops
  class ModelIndex
    include Clevic::TableIndex
  end

  class ItemSelectionModel
    # return an array of integer indexes for currently selected rows
    def row_indexes
      selected_indexes.inject(Set.new) do |set,index|
        set << index.row
      end.to_a
    end
  end
end
