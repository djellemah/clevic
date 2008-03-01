# require AR
require 'rubygems'
require 'active_record'
require 'active_record/dirty.rb'

$options[:database] ||= 'accounts'

class Entry < ActiveRecord::Base
  include ActiveRecord::Dirty
  belongs_to :debit, :class_name => 'Account', :foreign_key => 'debit_id'
  belongs_to :credit, :class_name => 'Account', :foreign_key => 'credit_id'

  def self.ui( parent )
    EntryTableView.new( Entry, parent ).create_model do |t|
      t.plain       :date, :sample => '28-Dec-08'
      t.distinct    :description, :sample => '12345678901234567890123456'
      t.relational  :debit, 'name', :sample => 'Leilani Member Loan', :class_name => 'Account', :conditions => 'active = true', :order => 'lower(name)'
      t.relational  :credit, 'name', :sample => 'Leilani Member Loan', :class_name => 'Account', :conditions => 'active = true', :order => 'lower(name)'
      t.plain       :amount, :sample => '100000.00'
      t.plain       :cheque_number, :sample => '0000'
      t.plain       :active, :sample => 'Active'
      t.plain       :vat, :sample => 'VAT', :label => 'VAT'
      
      t.collection = Entry.find( :all, :order => 'date, id' )
    end
  end
end

class Account < ActiveRecord::Base
  include ActiveRecord::Dirty
  has_many :debits, :class_name => 'Entry', :foreign_key => 'debit_id'
  has_many :credits, :class_name => 'Entry', :foreign_key => 'credit_id'
  
  def self.ui( parent )
    EntryTableView.new( Account, parent ).create_model do |t|
      t.plain :name
      t.plain :vat
      t.plain :account_type
      t.plain :pastel_number
      t.plain :fringe
      t.plain :active
      
      t.collection = Account.find( :all, :order => 'id' )
    end
  end
end
