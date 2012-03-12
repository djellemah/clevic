$options ||= {}
$options[:debug] = true

require 'clevic.rb'
require 'sequel'
host = ENV['PGHOST'] || 'localhost'

constring =
if RUBY_PLATFORM == 'java'
  "jdbc:postgresql://#{host}/times_test"
else
  "postgres://#{host}/times_test"
end

Sequel.connect constring

require 'times_models.rb'
