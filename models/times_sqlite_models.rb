require 'clevic.rb'
require 'sequel'

path = "#{ENV['HOME']}/projects/clevic/models/times.sqlite3"

constring =
if RUBY_PLATFORM == 'java'
  "jdbc:sqlite://#{path}"
else
  "sqlite://#{path}"
end

Sequel.connect constring

require 'times_models.rb'

# Sqlite needs this plugin cos it stores Date/Times as Strings
# and the driver doesn't translate them when loading

class Entry
  plugin :typecast_on_load, :date, :start, :end
end

class Invoice
  plugin :typecast_on_load, :quote_date, :date
end
