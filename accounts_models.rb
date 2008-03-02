# require AR
require 'rubygems'
require 'active_record'
require 'active_record/dirty.rb'
require 'cache_table.rb'

$options ||= {}
$options[:database] ||= 'accounts'

class Entry < ActiveRecord::Base
  include ActiveRecord::Dirty
  belongs_to :debit, :class_name => 'Account', :foreign_key => 'debit_id'
  belongs_to :credit, :class_name => 'Account', :foreign_key => 'credit_id'

  def self.ui( parent )
    EntryTableView.new( self, parent ).create_model do |t|
      t.plain       :date, :sample => '88-WWW-99'
      t.distinct    :description, :conditions => "now() - date <= '1 year'", :sample => 'm' * 26
      t.relational  :debit, 'name', :class_name => 'Account', :conditions => 'active = true', :order => 'lower(name)', :sample => 'Leilani Member Loan'
      t.relational  :credit, 'name', :class_name => 'Account', :conditions => 'active = true', :order => 'lower(name)', :sample => 'Leilani Member Loan'
      t.plain       :amount, :sample => 999999.99
      t.plain       :cheque_number
      t.plain       :active, :sample => 'WW'
      t.plain       :vat, :label => 'VAT', :sample => 'WW'
      
      #~ t.collection = self.find( :all, :order => 'date, id' )
      t.collection = CacheTable.new( self, :order => 'date, id' )
    end
  end
end

class Account < ActiveRecord::Base
  include ActiveRecord::Dirty
  has_many :debits, :class_name => 'Entry', :foreign_key => 'debit_id'
  has_many :credits, :class_name => 'Entry', :foreign_key => 'credit_id'
  
  def self.ui( parent )
    EntryTableView.new( self, parent ).create_model do |t|
      t.plain       :name
      t.restricted  :vat, :label => 'VAT', :set => %w{ yes no all }, :sample => 'www'
      t.plain       :account_type
      t.plain       :pastel_number, :alignment => Qt::AlignRight, :label => 'Pastel'
      t.plain       :fringe, :format => "%.1f"
      t.plain       :active
      
      #~ t.collection = CacheTable.new( self, :order => 'account_type,name' )
      t.collection = self.find( :all, :order => 'account_type,name' )
    end
  end
end

$options[:models] = [ Entry, Account ]

#~ class Values < ActiveRecord::Base
  #~ include ActiveRecord::Dirty
  #~ set_table_name 'values'
  #~ has_many :debits, :class_name => 'Entry', :foreign_key => 'debit_id'
  #~ has_many :credits, :class_name => 'Entry', :foreign_key => 'credit_id'
  #~ def self.ui( parent )
    #~ EntryTableView.new( self, parent ).create_model do |t|
      #~ t.plain       :date
      #~ t.plain       :description
      #~ t.plain       :debit
      #~ t.plain       :credit
      #~ t.plain       :pre_vat_amount
      #~ t.plain       :cheque_number
      #~ t.plain       :vat, :label => 'VAT'
      #~ t.plain       :financial_year
      #~ t.plain       :month
      
      #~ t.collection = CacheTable.new( self, :order => 'date' )
    #~ end
  #~ end
#~ end
