require File.dirname(__FILE__) + '/test_helper'

class TestModelIndex < Test::Unit::TestCase
  def self.startup
  end
  
  def self.shutdown
  end
  
  def setup
    @model = Qt::StandardItemModel.new( 4, 4 )
    ( 0...@model.row_count ).each do |i|
      ( 0...@model.column_count ).each do |j|
        @model.set_item( i, j, Qt::StandardItem.new( "location: (#{i},#{j})" ) )
      end
    end
    @zero_index = @model.create_index(0,0)
  end
  
  def teardown
  end
  
  should "be valid" do
    assert @zero_index.valid?
  end
  
  should_eventually "be invalid" do
    mi = @model.create_index( @model.row_count+1, @model.column_count+1 )
    assert !mi.valid?
  end
  
  should 'be an invalid clone of an invalid index' do
    clone = Qt::ModelIndex.invalid.clone
    assert !clone.valid?
  end
  
  should "be a valid exact clone" do
    clone = @zero_index.clone
    assert clone.valid?
  end

  should 'be an invalid clone' do
    clone = @zero_index.clone( :row => @model.row_count )
    assert !clone.valid?
    
    clone = @zero_index.clone( :column => @model.column_count )
    assert !clone.valid?
  end
  
  should 'be a clone with a changed row and column, from hash' do
    clone = @zero_index.clone( :row => 1, :column => 2)
    assert clone.valid?
    assert_equal 1, clone.row
    assert_equal 2, clone.column
  end

  should 'be a clone with incremented row and column, from block' do
    clone = @zero_index.clone do |i|
      i.row += 1
      i.column += 2
    end
    assert clone.valid?
    assert_equal 1, clone.row
    assert_equal 2, clone.column
  end
  
  should 'be a clone with changed row and column, from parameters' do
    clone = @zero_index.clone(3,0)
    assert clone.valid?
    assert_equal 3, clone.row
    assert_equal 0, clone.column
  end
  
  should 'raise an exception because parameters are wrong' do
    assert_raise TypeError do
      @zero_index.clone( 3 )
    end
  end
  
  should 'be a clone with decremented row and column, from block' do
    two_index = @model.create_index(2,2)
    
    clone = two_index.clone do |i|
      i.row -= 1
      i.column -= 2
    end
    assert clone.valid?
    assert_equal 1, clone.row
    assert_equal 0, clone.column
  end

  should 'be a clone with changed row and column, from block' do
    clone = @zero_index.clone do |i|
      i.row = 3
      i.column = 2
    end
    assert clone.valid?
    assert_equal 3, clone.row
    assert_equal 2, clone.column
  end

  should 'be a clone with changed row and column, from instance_eval' do
    clone = @zero_index.clone do
      row 3
      column 2
    end
    assert clone.valid?
    assert_equal 3, clone.row
    assert_equal 2, clone.column
  end
end
