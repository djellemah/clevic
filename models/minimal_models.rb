require 'clevic.rb'

# see sql/accounts.sql for schema

# db connection
Sequel.connect( "postgres://#{host}/accounts_test?user=#{$options[:username] || 'accounts'}&password=#{$options[:password]}" )

# minimal definition to get combo boxes to show up
class Entry < Sequel::Model
  include Clevic::Record
  many_to_one :debit, :class_name => 'Account', :foreign_key => 'debit_id'
  many_to_one :credit, :class_name => 'Account', :foreign_key => 'credit_id'
end

# minimal definition to get sensible values in combo boxes
class Account < ActiveRecord::Base
  include Clevic::Record
  def to_s; name; end
end
