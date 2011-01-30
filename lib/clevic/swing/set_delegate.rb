require 'clevic/swing/combo_delegate.rb'

module Clevic

# A Combo box which allows a set of values. May or may not
# be restricted to the set.
class SetDelegate < ComboDelegate
  def add_to_editor( item )
      if item.is_a?( Array )
        puts "#{__FILE__}:#{__LINE__}:probably can't deal with item: #{item.inspect}"
        # this is a hash-like set, so use key as db value
        # and value as display value
        class << item
          def toString; last; end
        end
      else
        class << item
          def toString; self; end
        end
      end
      editor << item
    end
  end
end

end
