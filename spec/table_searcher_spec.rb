require_relative 'spec_helper.rb'
require_relative 'fixtures.rb'

require 'rspec'
require 'clevic/table_searcher.rb'
require "clevic.rb"

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

describe Clevic::TableSearcher do
  before :all do
    Fixtures.up
    Fixtures::DB[:passengers].delete
    CreateFakePassengers.new( Fixtures::DB ).up

    # force Passenger to re-read db_schema
    Passenger.dataset = Passenger.dataset
  end

  after :all do
    CreateFakePassengers.new( Fixtures::DB ).down
    Fixtures.down
  end

  before :each do
    @simple_search_criteria = MockSearchCriteria.new
    @name_field = Clevic::Field.new( :name, Passenger, {} )
    @nationality_field = Clevic::Field.new( :nationality, Passenger, {} )
    @all_passengers = Passenger.filter( :flight_id => Flight.first.id ).order( :id ).all
  end

  context 'on initialisation' do
    it "have a matching field attribute on construction" do
      ts = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @name_field )
      @name_field.attribute.should == ts.field.attribute
    end

    it "throw an exception when called with no field" do
      -> do
        Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, nil )
      end.should raise_error( RuntimeError )
    end

    it 'throw an exception for an unknown direction' do
      @simple_search_criteria.direction = :other
      -> do
        table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @nationality_field )
      end.should raise_error( RuntimeError )
    end

  end

  context "searching" do
    before :each do
      @simple_search_criteria.search_text = CreateFakePassengers::NATIONALITIES[0]
      @passenger_generator = @all_passengers.to_enum
      @simple_search_criteria.from_start = true
    end

    it "have #{CreateFakePassengers::MAX_PASSENGERS} passengers" do
      CreateFakePassengers::MAX_PASSENGERS.should == Passenger.count
    end

    it "work with several ordering fields"
    # Sequel::SQL::OrderedExpression:0xb50a3b14 @expression=:date, @descending=false

    it "do more granular testing"

    it "find the first record" do
      table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @nationality_field )
      table_searcher.send( :comparator ).should == '>'
      @all_passengers.first.should == table_searcher.search
    end

    it "backwards-find the last record" do
      @simple_search_criteria.direction = :backwards
      table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @nationality_field )
      table_searcher.send( :comparator ).should == '<'
      @all_passengers.last.should == table_searcher.search
    end

    it "backwards-find the next-to-last record" do
      # find the last record
      @simple_search_criteria.direction = :backwards
      table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @nationality_field )
      last = table_searcher.search

      # now find the previous record
      @simple_search_criteria.from_start = false
      @all_passengers[-2].should == table_searcher.search( last )
    end

    it "find next records" do
      @simple_search_criteria.from_start = false
      table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @nationality_field )

      # fetch records one by one, starting from the one after the first one, and compare them
      while next_entity = table_searcher.search( @passenger_generator.next )
        passenger = @passenger_generator.next

        next_entity.should == passenger
        @all_passengers.first.should_not == passenger

        last_entity = next_entity
      end
    end
  end

  context 'search for related field value' do
    before :each do
      @simple_search_criteria.from_start = true
      # trim search slightly
      @simple_search_criteria.search_text = Flight.first.number[1..-2]
      @flight_field = Clevic::Field.new( :flight, Passenger, { :display => 'number' } )
    end

    it 'raise an exception for no display value' do
      @flight_field = Clevic::Field.new( :flight, Passenger, {} )

      @flight_field.display = nil

      -> do
        table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @flight_field )
        table_searcher.search
      end.should raise_error( RuntimeError )
    end

    it "raise exception for related fields with display procs" do
      lambda do
        table_searcher = Clevic::TableSearcher.new(
          Passenger.dataset,
          @simple_search_criteria,
          Clevic::Field.new( :flight, Passenger, { :display => lambda{|x| x.name} } )
        )
        table_searcher.search
      end.should raise_error( RuntimeError )
    end

    it 'find a record with partial words' do
      table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @flight_field )
      @all_passengers.first.should == table_searcher.search
    end

    it 'find a record with whole words' do
      @simple_search_criteria.whole_words = true
      @simple_search_criteria.search_text = Flight.first.number

      table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @flight_field )
      @all_passengers.first.should == table_searcher.search
    end
  end

  context 'whole words' do
    before :each do
      @simple_search_criteria.from_start = true
      @simple_search_criteria.search_text = CreateFakePassengers::NATIONALITIES[0][0..-3]
      @should_find = Passenger.filter( "nationality like '%#{@simple_search_criteria.search_text}%'" ).order( :id )
    end

    it 'find a full value with a partial search string' do
      @simple_search_criteria.whole_words = false
      @simple_search_criteria.from_start = true
      table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @nationality_field )
      expecteds = @should_find.to_enum
      last_entity = nil
      while next_entity = table_searcher.search( last_entity )
        next_entity.should == expecteds.next
        last_entity = next_entity
        @simple_search_criteria.from_start = false
      end
    end

    it 'not find any values with a partial search string and whole_words enabled' do
      @simple_search_criteria.whole_words = true
      @simple_search_criteria.from_start = true
      table_searcher = Clevic::TableSearcher.new( Passenger.dataset, @simple_search_criteria, @nationality_field )
      table_searcher.search.should be_nil
    end
  end

end
