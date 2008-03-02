# require AR
require 'rubygems'
require 'active_record'
require 'active_record/dirty.rb'

$options ||= {}
$options[:database] ||= 'accounts'

class Entry < ActiveRecord::Base
  include ActiveRecord::Dirty
  belongs_to :debit, :class_name => 'Account', :foreign_key => 'debit_id'
  belongs_to :credit, :class_name => 'Account', :foreign_key => 'credit_id'

  def self.ui( parent )
    EntryTableView.new( Entry, parent ).create_model do |t|
      t.plain       :date
      t.distinct    :description
      t.relational  :debit, 'name', :class_name => 'Account', :conditions => 'active = true', :order => 'lower(name)'
      t.relational  :credit, 'name', :class_name => 'Account', :conditions => 'active = true', :order => 'lower(name)'
      t.plain       :amount
      t.plain       :cheque_number
      t.plain       :active
      t.plain       :vat, :label => 'VAT'
      
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
      t.plain       :name
      t.restricted  :vat, :label => 'VAT', :set => %w{ yes no all }
      t.plain       :account_type
      t.plain       :pastel_number, :alignment => Qt::AlignRight, :label => 'Pastel'
      t.plain       :fringe, :format => "%.1f"
      t.plain       :active
      
      t.collection = Account.find( :all, :order => 'account_type,name' )
    end
  end
end
