gem "test-unit" unless RUBY_VERSION < '1.9.0'

require 'test/unit'
require 'shoulda'

require File.dirname(__FILE__) + '/../lib/clevic'
require File.dirname(__FILE__) + '/fixtures.rb'

if RUBY_VERSION < '1.9.0'
  require 'generator'
  Enumerator = Generator
end

# Allow running of startup and shutdown things before
# an entire suite, instead of just one per test
class SuiteWrapper < Test::Unit::TestSuite
  attr_accessor :tests, :db

  def initialize( name, test_case )
    super( name )
    @test_case = test_case

    # define in fixtures.rb
    @db = $db
  end

  def startup
    CreateFlights.new( db ).up
    CreatePassengers.new( db ).up
    PopulateCachePassengers.new( db ).up

    Flight.columns
    Passenger.columns
  end

  def shutdown
    PopulateCachePassengers.new( db ).down
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
