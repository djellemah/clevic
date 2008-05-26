require 'clevic.rb'

$options ||= {}
$options[:database] ||= $options[:debug] ? 'accounts_test' : 'accounts'
$options[:adapter]  ||= 'postgresql'
$options[:host] ||= 'localhost'
$options[:username] ||= 'panic'
$options[:password] ||= ''

class Entry < ActiveRecord::Base
  include ActiveRecord::Dirty
  belongs_to :debit, :class_name => 'Account', :foreign_key => 'debit_id'
  belongs_to :credit, :class_name => 'Account', :foreign_key => 'credit_id'

  def self.ui( parent )
    Clevic::TableView.new( self, parent ).create_model do
      plain       :date, :sample => '88-WWW-99'
      distinct    :description, :conditions => "now() - date <= '1 year'", :sample => 'm' * 26
      relational  :debit, 'name', :class_name => 'Account', :conditions => 'active = true', :order => 'lower(name)', :sample => 'Leilani Member Loan'
      relational  :credit, 'name', :class_name => 'Account', :conditions => 'active = true', :order => 'lower(name)', :sample => 'Leilani Member Loan'
      plain       :amount, :sample => 999999.99
      distinct    :category
      plain       :cheque_number
      plain       :active, :sample => 'WW'
      plain       :vat, :label => 'VAT', :sample => 'WW', :tooltip => 'Does this include VAT?'
      
      records     :order => 'date, id'
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
        # set the values
        current_index.entity.debit = similar.debit
        current_index.entity.credit = similar.credit
        current_index.entity.category = similar.category
        
        # update view from top_left to bottom_right
        model = current_index.model
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
    Clevic::TableView.new( self, parent ).create_model do
      plain       :name
      restricted  :vat, :label => 'VAT', :set => %w{ yes no all }
      plain       :account_type
      plain       :pastel_number, :alignment => Qt::AlignRight, :label => 'Pastel'
      plain       :fringe, :format => "%.1f"
      plain       :active
      
      records  :order => 'name,account_type'
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
    #~ Clevic::TableView.new( self, parent ).create_model do
      #~ readonly
      #~ plain       :date
      #~ plain       :description
      #~ plain       :debit
      #~ plain       :credit
      #~ plain       :pre_vat_amount
      #~ plain       :cheque_number
      #~ plain       :vat, :label => 'VAT'
      #~ plain       :financial_year
      #~ plain       :month
      
      #~ records :order => 'date'
    #~ end
  #~ end
#~ end
