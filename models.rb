# require AR
require 'rubygems'
require 'active_record'
require 'active_record/dirty.rb'

# connect to the database
ActiveRecord::Base.establish_connection({
  :adapter  => "postgresql",
  :database => "times",
  :username => "panic",
  :password => ""
})

# A replacement for the ActiveRecord::Dirty module.
# This module is not used
module SimpleChanged
  def changed?
    @changed ||= false
  end
  
  def changed=( value )
    @changed = value
  end

  def save
    super
    @changed = false
  end
end

class Entry < ActiveRecord::Base
  # Actually, it isn't this that's causing the currval error
  include ActiveRecord::Dirty
  belongs_to :invoice
  belongs_to :activity
  belongs_to :project
end

class Project < ActiveRecord::Base
  has_many :entries
end

class Activity < ActiveRecord::Base
  has_many :entries
end

class Invoice < ActiveRecord::Base
  has_many :entries
end
