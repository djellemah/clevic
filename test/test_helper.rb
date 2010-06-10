require 'test/unit'
require 'shoulda'

require File.dirname(__FILE__) + '/../lib/clevic'

require 'sequel'
require 'faker'
require 'generator'

# Doesn't seem to be a good place to put this
$db = Sequel.sqlite
Sequel.extension :migration

class Flight < Sequel::Model
  one_to_many :passengers
end

class Passenger < Sequel::Model
  many_to_one :flight
end

class CreateFlights < Sequel::Migration
  def up
    # this executes in the context of a Sequel::Database
    create_table :flights do
      primary_key :id
      String :number
      String :airline
      String :destination
    end
    
    self[:flights].tap do |fs|
      fs.insert :number => 'EK211'
      fs.insert :number => 'EK761'
      fs.insert :number => 'BA264'
    end
  end
  
  def down
    drop_table :flights
  end
end

class CreatePassengers < Sequel::Migration
  def up
    create_table :passengers do
      primary_key :id
      String :name
      String :nationality
      Integer :flight_id
      Integer :row
      String :seat
    end
  end
  
  def down
    drop_table :passengers
  end
end

# Allow running of startup and shutdown things before
# an entire suite, instead of just one per test
class SuiteWrapper < Test::Unit::TestSuite
  attr_accessor :tests, :db
  
  def initialize( name, test_case )
    super( name )
    @test_case = test_case
    @db = $db
  end
  
  def startup
    CreateFlights.new( db ).up
    CreatePassengers.new( db ).up
  end
  
  def shutdown
    CreatePassengers.new( db ).down
    CreateFlights.new( db ).down
  end
  
  def run( *args )
    startup
    @test_case.startup if @test_case.respond_to? :startup
    retval = super
    @test_case.shutdown if @test_case.respond_to? :shutdown
    shutdown
    retval
  end
end

module Test
  module Unit
    class TestCase
      unless respond_to? :old_suite
        class << self
          alias_method :old_suite, :suite
        end
        
        def self.suite
          os = old_suite
          sw = SuiteWrapper.new( os.name, self )
          sw.tests = os.tests
          sw
        end
      end
    end
  end
end
