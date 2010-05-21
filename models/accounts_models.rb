require 'clevic.rb'

# db connection
Clevic::DbOptions.connect( $options ) do
  # use a different db for testing, so real data doesn't get broken.
  if options[:database].nil? || options[:database].empty?
    database( debug? ? :accounts_test : :accounts )
  else
    database options[:database]
  end
  # for AR
  #~ adapter :postgresql
  # for Sequel
  adapter :postgres
  username options[:username].blank? ? 'accounts' : options[:username]
end

class Entry < Sequel::Model
  belongs_to :debit, :class_name => 'Account', :foreign_key => 'debit_id'
  belongs_to :credit, :class_name => 'Account', :foreign_key => 'credit_id'
  
  include Clevic::Record
  
  define_ui do
    plain       :date, :sample => '88-WWW-99'
    distinct    :description do |f|
      f.conditions "now() - date <= '1 year'"
      f.sample( 'm' * 26 )
      f.notify_data_changed = lambda do |entity_view, table_view, model_index|
        if model_index.entity.credit.nil? && model_index.entity.debit.nil?
          entity_view.update_from_description( model_index )
          
          # move edit cursor to amount field
          table_view.selection_model.clear
          table_view.override_next_index( model_index.choppy( :column => :amount ) )
        end
      end
    end
    relational  :debit, :display => 'name', :conditions => 'active = true', :order => 'lower(name)', :sample => 'Leilani Member Loan'
    relational  :credit, :display => 'name', :conditions => 'active = true', :order => 'lower(name)', :sample => 'Leilani Member Loan'
    plain       :amount, :sample => 999999.99
    distinct    :category
    plain       :cheque_number
    plain       :active, :sample => 'WW'
    plain       :vat, :label => 'VAT', :sample => 'WW', :tooltip => 'Does this include VAT?'
    
    records     :order => 'date, id'
  end
  
  # Copy the values for the credit and debit fields
  # from the previous similar entry with a similar description
  def self.update_from_description( current_index )
    return if current_index.attribute_value.nil?
    # most recent entry, ordered in reverse
    similar = self.adaptor.find(
      :first,
      :conditions => ["#{current_index.attribute} = ?", current_index.attribute_value],
      :order => 'date desc'
    )
    if similar != nil
      # set the values
      current_index.entity.debit = similar.debit
      current_index.entity.credit = similar.credit
      current_index.entity.category = similar.category
      
      # emit signal to that whole row has changed
      current_index.model.data_changed do |change|
        change.top_left = current_index.choppy( :column => 0 )
        change.bottom_right = current_index.choppy( :column => current_index.model.column_count - 1 )
      end
    end
  end
end

class Account < Sequel::Model
  has_many :debits, :class_name => 'Entry', :foreign_key => 'debit_id'
  has_many :credits, :class_name => 'Entry', :foreign_key => 'credit_id'
  
  include Clevic::Record
  
  # define how fields are displayed
  define_ui do
    plain       :name
    restricted  :vat, :label => 'VAT', :set => %w{ yes no all }
    restricted  :account_type, :set => %w{Account Asset Assets Expenses Income Liability Opening Balance Personal Tax VAT}
    plain       :pastel_number, :alignment => Qt::AlignRight, :label => 'Pastel'
    plain       :fringe, :format => "%.1f"
    plain       :active
    
    records  :order => 'name,account_type'
  end
end
