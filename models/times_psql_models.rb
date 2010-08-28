$options ||= {}

require 'clevic.rb'

Sequel.connect( "jdbc:postgresql://localhost/times_test?user=#{$options[:username] || 'times'}&password=general" )

require 'times_models.rb'
