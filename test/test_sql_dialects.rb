require File.dirname(__FILE__) + '/test_helper.rb'
require 'clevic/sql_dialects.rb'

# TODO should probably connect to real DB drivers to do this

class MockPostgreSQL
  include Clevic::SqlDialects
  def adapter_name
    'PostgreSQL'
  end
  
  def connection
    self
  end
  
end

class MockOther
  include Clevic::SqlDialects
  def adapter_name
    'Something else entirely'
  end
  
  def connection
    self
  end
  
  def quoted_true; "'t'"; end
  def quoted_false; "'f'"; end
end

class TestSqlDialects < Test::Unit::TestCase
  def self.startup
  end
  
  def self.shutdown
  end
  
  def setup
  end
  
  context MockPostgreSQL.name do
    setup do
      @dialect = MockPostgreSQL.new
    end
    
    should 'return ilike' do
      assert_equal 'ilike', @dialect.like_operator
    end
    
    should "return true" do
      assert_equal "true", @dialect.sql_boolean( true )
    end
    
    should "return false" do
      assert_equal "false", @dialect.sql_boolean( false )
    end
  end
  
  context MockOther.name do
    setup do
      @dialect = MockOther.new
    end
    
    should 'return like' do
      assert_equal 'like', @dialect.like_operator
    end
    
    should "return 't'" do
      assert_equal "'t'", @dialect.sql_boolean( true )
    end
    
    should "return 'f'" do
      assert_equal "'f'", @dialect.sql_boolean( false )
    end
  end
end
