require 'active_record'

module Clevic
=begin rdoc
This class is intended to set up db options for a ActiveRecord
connection to a particular database. Like this:

  Clevic::DbOptions.connect( $options ) do
    database :accounts
    adapter :postgresql
    username 'accounts_user'
  end

When the block ends, a check is done to see that the :database key
exists. If not and exception is thrown. Finally the relevant calls to
ActiveRecord are performed.

Method calls are translated to insertions into a hash with the same
key as the method being called. The hash is initialised
with the options value passed in (in this case $options).
Values have to_s called on them so they can be symbols or strings.
=end
class DbOptions
  attr_reader :options
  
  def initialize( options = nil )
    @options = options || {}
    # make sure the relevant entries exist, so method_missing works
    @options[:adapter] ||= ''
    @options[:host] ||= ''
    @options[:username] ||= ''
    @options[:password] ||= ''
    @options[:database] ||= ''
    @options[:models] ||= []
  end
  
  def models=( arr )
    @options[:models] ||= arr
  end
  
  def connect( *args, &block )
    # using the Rails implementation, included in Qt
    block.bind( self )[*args]
    do_connection
  end
  
  # do error checking and make the ActiveRecord connection calls.
  def do_connection
    unless @options[:database]
      raise "Please define database using DbOptions"
    end
    
    # connect to db
    ActiveRecord::Base.establish_connection( options )
    ActiveRecord::Base.logger = Logger.new(STDOUT) if options[:verbose]
    #~ ActiveRecord.colorize_logging = @options[:verbose]
    puts "using database #{ActiveRecord::Base.connection.raw_connection.db}" if options[:debug]
    self
  end
  
  # convenience method so we can do things like
  #   Clevic::DbOptions.connect( $options ) do
  #     database :accounts
  #     adapter :postgresql
  #     username 'accounts_user'
  #   end
  # the block is evaluated in the context of the a new DbOptions
  # object.
  def self.connect( args = nil, &block )
    inst = self.new( args )
    # using the Rails implementation, included in Qt
    block.bind( inst )[*args]
    inst.do_connection
  end
  
  # translate method calls in the context of an instance
  # of this object to setting values in the @options
  # variable
  def method_missing(meth, *args, &block)
    if @options.has_key? meth.to_sym
      @options[meth.to_sym] = args[0].to_s
    else
      super
    end
  end
  
  # convenience to find out if we're in debug mode
  def debug?
    @options[:debug] == true
  end
end

end

# workaround for the date freeze issue
class Date
  def freeze
    self
  end
end

