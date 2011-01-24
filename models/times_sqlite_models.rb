require 'clevic.rb'
Sequel.sqlite( "#{ENV['HOME']}/projects/clevic-sequel/times.sqlite3" )
require 'times_models.rb'
