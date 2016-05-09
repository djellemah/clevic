require_relative 'spec_helper.rb'
require_relative 'fixtures.rb'
require 'clevic/cache_table'

describe Clevic::CacheTable do
  before :all do Fixtures.up end
  after :all do Fixtures.down end

  before :each do
    @cache_table = Clevic::CacheTable.new( Passenger )
  end

  it 'passenger_count' do
    Passenger.count.should == 100
  end

  it "have a sql_count equal to number of records" do
    Passenger.count.should == @cache_table.sql_count
  end

  it "have a size equal to number of records" do
    Passenger.count.should == @cache_table.size
  end

  describe 'cache_loading' do
    it 'not yet cached' do
      (0...Passenger.count).each do |i|
        @cache_table.cached_at?(i).should == false
      end
    end

    it 'test cache retrieval' do
      (0...Passenger.count).each do |offset|
        @cache_table[offset].should == Passenger.limit(1,offset).first
      end
    end
  end

  it 'preload_limit_1' do
    @cache_table.preload_limit 1 do
      @cache_table[0].should_not be_nil
      (1...Passenger.count).each do |i|
        @cache_table.cached_at?(i).should == false
      end
    end
  end

  # make sure preloads are done
  it 'preload_limit_default' do
    (0...Passenger.count).map{|i| @cache_table.cached_at?(i)}.uniq.should == [false]

    # force retrieval
    @cache_table[0]

    # check that only preload is loaded
    (0...@cache_table.preload_count).map{|i| @cache_table.cached_at?(i)}.uniq.should == [true]
    (@cache_table.preload_count...Passenger.count).map{|i| @cache_table.cached_at?(i)}.uniq.should == [false]
  end

  it 'return nil for a nil parameter' do
    @cache_table.index_for_entity( nil ).should be_nil
  end

  it 'return nil for an empty set' do
    cache_table = @cache_table.renew do |dataset|
      dataset.filter( :nationality => 'nothing' )
    end
    cache_table.index_for_entity( Passenger.first ).should be_nil
  end

  it "filter with related objects" do
    @cache_table = @cache_table.renew do |dataset|
      dataset.filter( :flight_id => Flight.first.id )
    end
  end

  it 'index_for_entity' do
    # test in ascending order
    first_passenger = Passenger.first
    index = @cache_table.index_for_entity( first_passenger )
    index.should == 0

    # test in descending order
    @cache_table = @cache_table.renew {|ds| ds.order( :id.desc ) }
    last_passenger = Passenger.order( :id.desc ).first
    @cache_table.index_for_entity( last_passenger ).should == 0

    # test with two order fields
    @cache_table = @cache_table.renew {|ds| ds.order( :nationality, :row ) }
    passenger = Passenger.order( :nationality, :row ).first
    @cache_table.index_for_entity( passenger ).should == 0
  end
end
