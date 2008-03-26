require 'rubygems'
require 'active_record'
require 'active_record/dirty.rb'

require 'clevic/cache_table.rb'

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
      
      t.collection = CacheTable.new( self, :order => 'date, id' )
    end
  end
  
  def self.data_changed( top_left, bottom_right, view )
    if top_left == bottom_right
      update_credit_debit( top_left, view )
    else
      puts "top_left: #{top_left.inspect}"
      puts "bottom_right: #{bottom_right.inspect}"
      puts "can't do data_changed for a range"
    end
  end
  
  # check that the current field is :descriptions, then
  # copy the values for the credit and debit fields
  # from the previous similar entry
  def self.update_credit_debit( current_index, view )
    return if !current_index.valid?
    current_field = current_index.attribute
    if current_field == :description
      # most recent entry, ordered in reverse
      similar = self.find(
        :first,
        :conditions => ["#{current_field} = ?", current_index.attribute_value],
        :order => 'date desc'
      )
      if similar != nil
        model = current_index.model
        
        # fetch the current ActiveRecord object and set the values
        current_item = model.collection[current_index.row]
        current_item.debit = similar.debit
        current_item.credit = similar.credit
        
        # update view from top_left to bottom_right
        top_left_index = model.create_index( current_index.row, 0 )
        bottom_right_index = model.create_index( current_index.row, view.builder.fields.size )
        view.dataChanged( top_left_index, bottom_right_index )
        
        # move edit cursor to amount field
        view.selection_model.clear
        view.override_next_index( model.create_index( current_index.row, view.builder.index( :amount ) ) )
      end
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
      
      t.collection = self.find( :all, :order => 'name,account_type' )
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
