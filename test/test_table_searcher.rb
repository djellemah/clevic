require 'generator'

require File.dirname(__FILE__) + '/test_helper.rb'
require 'clevic/table_searcher.rb'

class MockSearchCriteria
  def initialize( &block )
    @direction = :forwards
    @from_start = false
    @whole_words = false
    self.instance_eval( &block ) if block_given?
  end
  
  attr_accessor :direction, :search_text
  attr_writer :whole_words, :from_start
  def whole_words?; @whole_words; end
  def from_start?; @from_start; end
end

class TestTableSearcher < Test::Unit::TestCase
  def self.startup
    suite.db[:passengers].delete
    CreateFakePassengers.new( suite.db ).up
  end
  
  def self.shutdown
    CreateFakePassengers.new( suite.db ).down
  end
  
  def setup
    @simple_search_criteria = MockSearchCriteria.new
    @name_field = Clevic::Field.new( :name, Passenger, {} )
    @nationality_field = Clevic::Field.new( :nationality, Passenger, {} )
    @all_passengers = Passenger.filter( :flight_id => Flight.first.id ).order( :id ).all
  end

  context 'on initialisation' do
    should "have a matching field attribute on construction" do
      ts = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @name_field )
      assert_equal @name_field.attribute, ts.field.attribute
    end

    should "throw an exception when called with no field" do
      assert_raise( RuntimeError ) do
        Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, nil )
      end
    end
  
    should 'throw an exception for an unknown direction' do
      @simple_search_criteria.direction = :other
      assert_raise( RuntimeError ) do
        table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @nationality_field )
      end
    end
  end
  
  context "searching" do
    setup do
      @simple_search_criteria.search_text = CreateFakePassengers::NATIONALITIES[0]
      @passenger_generator = Generator.new( @all_passengers )
    end
    
    should "have #{CreateFakePassengers::MAX_PASSENGERS} passengers" do
      assert_equal CreateFakePassengers::MAX_PASSENGERS, Passenger.count
    end

    should_eventually "do more granular testing"
    
    should "find the first record" do
      @simple_search_criteria.from_start = true
      table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @nationality_field )
      assert_equal @all_passengers.first, table_searcher.search
    end
    
    should "backwards-find the last record" do
      @simple_search_criteria.from_start = true
      @simple_search_criteria.direction = :backwards
      table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @nationality_field )
      assert_equal "<", table_searcher.send( :comparator )
      assert_equal @all_passengers.last, table_searcher.search
    end
    
    should "backwards-find the next-to-last record" do
      # find the last record
      @simple_search_criteria.from_start = true
      @simple_search_criteria.direction = :backwards
      table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @nationality_field )
      last = table_searcher.search
      
      # now find the previous record
      @simple_search_criteria.from_start = false
      assert_equal @all_passengers[-2], table_searcher.search( last )
    end

    should "find next records" do
      @simple_search_criteria.from_start = false
      table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @nationality_field )
      
      # fetch records one by one, starting from the one after the first one, and compare them
      while next_entity = table_searcher.search( @passenger_generator.next )
        passenger = @passenger_generator.next
        
        assert_equal next_entity, passenger
        assert_not_equal @all_passengers.first, passenger
        
        last_entity = next_entity
      end
    end
  end
  
  context 'search for related field value' do
    should_eventually 'raise an exception for no display value' do
      @simple_search_criteria.from_start = true
      @simple_search_criteria.search_text = Flight.first.number
      flight_field = Clevic::Field.new( :flight, Passenger, {} )
      assert_nil flight_field.display
      assert_raise RuntimeError do
        table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, flight_field )
        table_searcher.search
      end
    end

    should_eventually 'find a record' do
      @simple_search_criteria.from_start = true
      puts "Flight.first: #{Flight.first.inspect}"
      @simple_search_criteria.search_text = Flight.first.number
      flight_field = Clevic::Field.new( :flight, Passenger, { :display => 'number' } )
      table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, flight_field )
      assert_equal @all_passengers.first, table_searcher.search
    end
  end
  
  context 'whole words' do
    setup do
      @simple_search_criteria.from_start = true
      @simple_search_criteria.search_text = CreateFakePassengers::NATIONALITIES[0][0..-3]
      @should_find = Passenger.filter( "nationality like '%#{@simple_search_criteria.search_text}%'" ).order( :id )
    end
    
    should 'find a full value with a partial search string' do
      @simple_search_criteria.whole_words = false
      @simple_search_criteria.from_start = true
      table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @nationality_field )
      expecteds = Generator.new @should_find
      last_entity = nil
      while next_entity = table_searcher.search( last_entity )
        assert_equal next_entity, expecteds.next
        last_entity = next_entity
        @simple_search_criteria.from_start = false
      end
    end

    should 'not find any values with a partial search string and whole_words enabled' do
      @simple_search_criteria.whole_words = true
      @simple_search_criteria.from_start = true
      table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @nationality_field )
      assert_nil table_searcher.search
    end
  end
  
end
