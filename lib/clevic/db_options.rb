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
exists. If not, an exception is thrown. Finally the relevant calls to
establish the ActiveRecord connection are performed.

Method calls are translated to insertions into a hash with the same
key as the method being called. The hash is initialised
with the options value passed in (in this case $options).
Values have to_s called on them so they can be symbols or strings.
=end
class DbOptions
  attr_reader :options
  
  def initialize( options = nil, &block )
    @options = options || {}
    
    # make sure the relevant entries exist, so method_missing works
    @options[:adapter] ||= ''
    @options[:host] ||= 'localhost'
    @options[:username] ||= ''
    @options[:password] ||= ''
    @options[:database] ||= ''
    
    unless block.nil?
      if block.arity == -1
        instance_eval &block
      else
        yield self
      end
    end
  end
  
  def connect
    unless @options[:database]
      raise "Please define database using DbOptions"
    end
    
    # connect to db
    ActiveRecord::Base.establish_connection( options )
    ActiveRecord::Base.logger = Logger.new(STDOUT) if options[:verbose]
    #~ ActiveRecord.colorize_logging = @options[:verbose]
    if options[:debug] and ActiveRecord::Base.connection.raw_connection.respond_to? :db
      puts "using database #{ActiveRecord::Base.connection.raw_connection.db}"
    end
    self
  end
  
  # convenience method so we can do things like
  #   Clevic::DbOptions.connect( $options ) do
  #     database :accounts
  #     adapter :postgresql
  #     username 'accounts_user'
  #   end
  # the block is evaluated in the context of the a new DbOptions
  # object. You can also pass a block parameter and it will receive
  # the DbOptions instance, like this:
  #   Clevic::DbOptions.connect( $options ) do |dbo|
  #     dbo.database :accounts
  #     dbo.adapter :postgresql
  #     dbo.username 'accounts_user'
  #   end
  def self.connect( args = {}, &block )
    inst = self.new( args, &block    )
    inst.connect
    inst
  end
  
  # translate method calls in the context of an instance
  # of this object to setting values in the @options
  # variable
  def method_missing(meth, *args, &block)
    if @options.has_key? meth.to_sym
      if args.size == 0
        @options[meth.to_sym]
      else
        @options[meth.to_sym] = args[0].to_s
      end
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

# workaround for the date freeze issue, if it exists
begin
  Date.new.freeze.to_s
rescue TypeError
  class Date
    def freeze
      self
    end
  end
end
