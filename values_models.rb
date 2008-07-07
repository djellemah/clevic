require 'clevic.rb'

# db connection options
$options ||= {}
$options[:database] ||= $options[:debug] ? 'accounts_test' : 'accounts'
$options[:adapter]  ||= 'postgresql'
$options[:host] ||= 'localhost'
$options[:username] ||= 'panic'
$options[:password] ||= ''

# This is a read-only view, which is currently not implemented
class Values < ActiveRecord::Base
  include ActiveRecord::Dirty
  set_table_name 'values'
  has_many :debits, :class_name => 'Entry', :foreign_key => 'debit_id'
  has_many :credits, :class_name => 'Entry', :foreign_key => 'credit_id'
  def self.ui( parent )
    Clevic::TableView.new( self, parent ).create_model do
      readonly
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
end
