require 'clevic.rb'

# db connection
Clevic::DbOptions.connect( $options ) do
  database :accounts_test
  adapter :postgresql
  username 'accounts'
end

# This is a read-only view, which is currently not implemented
class Value < ActiveRecord::Base
  set_table_name 'values'
  #~ has_many :debits, :class_name => 'Entry', :foreign_key => 'debit_id'
  #~ has_many :credits, :class_name => 'Entry', :foreign_key => 'credit_id'
  
  include Clevic::Record
  define_ui do
    read_only!
    plain       :date
    plain       :description
    plain       :debit
    plain       :credit
    plain       :pre_vat_amount
    plain       :cheque_number
    plain       :vat, :label => 'VAT'
    plain       :financial_year
    plain       :month
    
    records :order => 'date'
  end
end
