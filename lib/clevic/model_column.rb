=begin rdoc
Field metadata class. Includes information for type, reflections etc.

Also, it eases the migration from AR to Sequel, which returns metadata as
a hash instead of a class.

Basically it stores a bunch of Sequel and AR specific values, and
occasionally needs to tweak one.
=end

require 'ostruct'

class ModelColumn < OpenStruct
  def initialize( name, hash )
    super(hash)

    # must be after hash so it takes precedence
    @name = name
  end

  attr_reader :name
  def association?; association; end

  # if it's not here, it's probably from Sequel, so figure it out from
  # the db_type
  def limit
    unless @limit
      db_type =~ /\((\d+)\)/
      @limit = $1.to_i
    end
    @limit
  end

  attr_writer :limit

  def related_class
    @related_class ||= eval class_name
  end
end
