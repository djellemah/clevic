require File.dirname(__FILE__) + '/test_helper'

class OtherThing < Clevic::HashCollector
  dsl_static
  dsl_accessor :thing, :other
end

class BuildOn < Clevic::HashCollector
  dsl_accessor :ook
end

class TestHashCollector < Test::Unit::TestCase
  def setup
    @hash = { :colour => :red, :hue => 15 }
    @collected_hash = { :saturation => 17, :opacity => 0.43, :grooviness => 100 }
    @full_hash = @hash.merge( @collected_hash )
    @collector = Clevic::HashCollector.new
  end
  
  def teardown
  end
  
  context 'static hash collector' do
    setup do
      @collector = OtherThing.new
    end
    
    should "throw NoMethodError on collection" do
      assert_raise( NoMethodError ) do
        @collector.collect { thing 2; blah 3 }
      end
      assert_raise( NoMethodError ) do
        @collector.collect {|c| c.blah = 3 }
      end
      assert_raise( NoMethodError ) { @collector.blah }
      assert_raise( NoMethodError ) { @collector.blah = 5 }
    end

    should "understand defined attributes" do
      assert_nothing_raised do
        @collector.collect do
          thing 1
          other 2
        end
      end
      
      assert_nothing_raised { @collector.thing = 2 }
      assert_nothing_raised { @collector.other = 4 }
    end
    
    should "be dynamic" do
      assert BuildOn.dynamic?
    end
  end
  
  def assert_collected( collector )
    assert_equal 17, collector.saturation
    assert_equal 0.43, collector.opacity
    assert_equal 100, collector.grooviness
  end
  
  def assert_hashed( collector )
    assert_equal :red, collector.colour
    assert_equal 15, collector.hue
  end
  
  should "collect from a hash" do
    @collector.collect( @hash )
    assert_equal @hash, @collector.to_hash
  end

  should 'not fail on a nil hash' do
    @collector.collect nil
    assert_equal 0, @collector.to_hash.size
  end
  
  should 'collect from a block, with dsl setters' do
    @collector.collect do
      saturation 17
      opacity 0.43
      grooviness 100
    end
    assert_collected( @collector )
    assert_equal @collected_hash, @collector.to_hash
  end

  should 'collect from a block, with = setters' do
    @collector.collect do |hc|
      hc.saturation = 17
      hc.opacity = 0.43
      hc.grooviness = 100
    end
    assert_collected( @collector )
    assert_equal @collected_hash, @collector.to_hash
  end
  
  should 'collect from a hash and block, with dsl setters' do
    @collector.collect( @hash ) do
      saturation 17
      opacity 0.43
      grooviness 100
    end
    assert_collected( @collector )
    assert_hashed( @collector )
    assert_equal @full_hash, @collector.to_hash
  end
  
  should 'collect from a hash and block with = setters' do
    @collector.collect( @hash ) do |hc|
      hc.saturation = 17
      hc.opacity = 0.43
      hc.grooviness = 100
    end
    assert_collected( @collector )
    assert_hashed( @collector )
    assert_equal @full_hash, @collector.to_hash
  end
  
  should 'not fail construction with a nil hash' do
    collector = Clevic::HashCollector.new nil
    assert_equal 0, @collector.to_hash.size
  end
  
  should 'construct from a hash and block, with dsl setters' do
    collector = Clevic::HashCollector.new( @hash ) do
      saturation 17
      opacity 0.43
      grooviness 100
    end
    assert_collected( collector )
    assert_hashed( collector )
    assert_equal @full_hash, collector.to_hash
  end
  
  should 'construct from a hash and block with = setters' do
    collector = Clevic::HashCollector.new( @hash ) do |hc|
      hc.saturation = 17
      hc.opacity = 0.43
      hc.grooviness = 100
    end
    assert_collected( collector )
    assert_hashed( collector )
    assert_equal @full_hash, collector.to_hash
  end
end
