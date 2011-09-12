require File.dirname(__FILE__) + '/test_helper'

class TestCacheTable < Test::Unit::TestCase
  def setup
    @cache_table = Clevic::CacheTable.new( Passenger )
  end

  def teardown
  end

  def test_passenger_count
    assert_equal 3, Passenger.count
  end

  should "have a sql_count equal to number of records" do
    assert_equal Passenger.count, @cache_table.sql_count
  end

  should "have a size equal to number of records" do
    assert_equal Passenger.count, @cache_table.size
  end

  def test_cache_loading
    # test not yet cached
    (0...Passenger.count).each do |i|
      assert @cache_table.cached_at?(i) == false, "record #{i} should not be cached yet"
    end

    # test cache retrieval
    (0...Passenger.count).each do |offset|
      assert @cache_table[offset] == Passenger.limit(1,offset).first, "#{offset}th cached record is not #{offset}th db record"
    end
  end

  def test_preload_limit_1
    @cache_table.preload_limit 1 do
      assert !@cache_table[0].nil?, 'First object should not be nil'
      (1...Passenger.count).each do |i|
        assert !@cache_table.cached_at?(i), "#{i}th object should be nil"
      end
    end
  end

  # make sure preloads are done
  def test_preload_limit_default
    (0...Passenger.count).each do |i|
      assert !@cache_table.cached_at?(i), "record #{i} should not be cached yet"
    end

    # force retrieval
    @cache_table[0]

    (0...Passenger.count).each do |i|
      assert @cache_table.cached_at?(i), "#{i}th object should not be nil"
    end
  end

  should 'return nil for a nil parameter' do
    assert_nil @cache_table.index_for_entity( nil )
  end

  should 'return nil for an empty set' do
    cache_table = @cache_table.renew do |dataset|
      dataset.filter( :nationality => 'nothing' )
    end
    assert_nil cache_table.index_for_entity( Passenger.first )
  end

  should "filter with related objects" do
    @cache_table = @cache_table.renew do |dataset|
      dataset.filter( :flight_id => Flight.first.id )
    end
  end

  def test_index_for_entity
    # test in ascending order
    first_passenger = Passenger.first
    index = @cache_table.index_for_entity( first_passenger )
    assert_equal 0, index, 'first passenger should have an index of 0'

    # test in descending order
    @cache_table = @cache_table.renew {|ds| ds.order( :id.desc ) }
    last_passenger = Passenger.order( :id.desc ).first
    assert_equal 0, @cache_table.index_for_entity( last_passenger ), "last passenger in reverse order should have an index of 0"

    # test with two order fields
    @cache_table = @cache_table.renew {|ds| ds.order( :nationality, :row ) }
    passenger = Passenger.order( :nationality, :row ).first
    assert_equal 0, @cache_table.index_for_entity( passenger ), "passenger in (nationality, row) order should have an index of 0"
  end
end
