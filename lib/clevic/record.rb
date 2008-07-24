module Clevic
  class Record < ActiveRecord::Base
    include ActiveRecord::Dirty
    self.abstract_class = true
  end
end
