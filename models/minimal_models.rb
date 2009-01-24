require 'clevic.rb'

# see sql/accounts.sql for schema

# db connection
Clevic::DbOptions.connect do
  database 'accounts_test'
  adapter :postgresql
  username 'accounts'
end

# minimal definition to get combo boxes to show up
class Entry < ActiveRecord::Base
  belongs_to :debit, :class_name => 'Account', :foreign_key => 'debit_id'
  belongs_to :credit, :class_name => 'Account', :foreign_key => 'credit_id'
end

# minimal definition to get sensible values in combo boxes
class Account < ActiveRecord::Base
  def to_s; name; end
end
