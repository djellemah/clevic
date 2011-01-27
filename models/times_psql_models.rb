$options ||= {}

require 'clevic.rb'
require 'sequel'
host = ENV['PGHOST'] || 'localhost'

constring =
if respond_to?( :'jruby?' ) && jruby?
  "jdbc:postgresql://#{host}/accounts_test"
else
  "postgres://#{host}/times_test"
end

Sequel.connect constring

require 'times_models.rb'
