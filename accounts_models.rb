# require AR
require 'rubygems'
require 'active_record'
require 'active_record/dirty.rb'

# connect to the database
puts "using test database"
ActiveRecord::Base.establish_connection({
  :adapter  => 'postgresql',
  :database => 'accounts_test',
  :username => 'panic',
  :password => ''
})

class Entry < ActiveRecord::Base
  include ActiveRecord::Dirty
  belongs_to :debit, :class_name => 'Account', :foreign_key => 'debit_id'
  belongs_to :credit, :class_name => 'Account', :foreign_key => 'credit_id'
end

class Account < ActiveRecord::Base
  has_many :debits, :class_name => 'Entry', :foreign_key => 'debit_id'
  has_many :credits, :class_name => 'Entry', :foreign_key => 'credit_id'
end
