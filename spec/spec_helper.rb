require File.dirname(__FILE__) + '/../test/test_helper.rb'

class CreateFakePassengers < ActiveRecord::Migration
  def self.flights
    %w{EK211 EK088 EK761 BA264}
  end
  
  MAX_PASSENGERS = 100
  
  def self.up
    1.upto( MAX_PASSENGERS ) do |i|
      Passenger.create :name => Faker::Name.name, :flight => flights[i % flights.size], :row => i, :seat => %w{A B C D}[i % 4]
    end
  end
  
  def self.down
    Passenger.delete_all
  end
end
