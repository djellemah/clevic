require 'test/unit'
require 'shoulda'

require File.dirname(__FILE__) + '/../lib/clevic'

require 'activerecord'
require 'sqlite3'
require 'faker'
require 'generator'


class Flight < ActiveRecord::Base
  has_many :passengers
end

class Passenger < ActiveRecord::Base
  belongs_to :flight
end

class CreateFlights < ActiveRecord::Migration
  def self.up
    create_table :flights do |t|
      t.string :number
      t.string :airline
      t.string :destination
    end
    Flight.reset_column_information
    Flight.create :number => 'EK211'
    Flight.create :number => 'EK088'
    Flight.create :number => 'EK761'
    Flight.create :number => 'BA264'
  end
  
  def self.down
    Flight.delete_all
  end
end

class CreatePassengers < ActiveRecord::Migration
  def self.up
    create_table :passengers do |t|
      t.string :name
      t.string :nationality
      t.integer :flight_id
      t.integer :row
      t.string :seat
    end
    Passenger.reset_column_information
  end
  
  def self.down
    Passenger.delete_all
  end
end

# Convenience class to create a test DB
class OneBase
  attr_reader :db_name, :adapter
  
  def initialize
    @db_name = 'test_cache_table.sqlite3'

    if File.exists? @db_name
      p 'remove old db'
      File.unlink @db_name
    end
    
    @adapter = :sqlite3
    @db = SQLite3::Database.new( @db_name )
    @db_options = Clevic::DbOptions.connect do |dbo|
      dbo.database @db_name
      dbo.adapter @adapter
    end
  end

  def feenesh
    File.unlink @db_name
  end
end

# Allow running of startup and shutdown things before
# an entire suite, instead of just one per test
class SuiteWrapper < Test::Unit::TestSuite
  attr_accessor :tests
  
  def initialize( name, test_case )
    super( name )
    @test_case = test_case
  end
  
  def startup
    @onebase = OneBase.new
    ActiveRecord::Migration.verbose = false
    CreateFlights.up
    CreatePassengers.up
  end
  
  def shutdown
    CreatePassengers.down
    CreateFlights.down
    @onebase.feenesh
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
