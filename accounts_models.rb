# require AR
require 'rubygems'
require 'active_record'
require 'active_record/dirty.rb'

# connect to the database
ActiveRecord::Base.establish_connection({
  :adapter  => 'postgresql',
  :database => 'racc',
  :username => 'panic',
  :password => ''
})

class Entry < ActiveRecord::Base
  # Actually, it isn't this that's causing the currval error
  include ActiveRecord::Dirty
  belongs_to :debit, :class_name => 'Account', :foreign_key => 'debit_id'
  belongs_to :credit, :class_name => 'Account', :foreign_key => 'credit_id'
  belongs_to :project
end

class Account < ActiveRecord::Base
  has_many :debits, :class_name => 'Entry', :foreign_key => 'debit_id'
  has_many :credits, :class_name => 'Entry', :foreign_key => 'credit_id'
end
