require 'clevic.rb'

# db connection
Sequel.connect( "postgres://#{host}/accounts_test?user=#{$options[:username] || 'accounts'}&password=#{$options[:password]}" )

# This is a read-only view, which is currently not implemented
class Value < Sequel::Model
  set_table_name 'values'
  
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
