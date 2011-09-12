require File.dirname(__FILE__) + '/test_helper'

class TestModelIndex < Test::Unit::TestCase
  def self.startup
  end

  def self.shutdown
  end

  def setup
  end

  def teardown
  end

  should_eventually 'test something'

  should 'be true' do
    assert true
  end

end
