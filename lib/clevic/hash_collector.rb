module Clevic

  class BlankSlate
    keep_methods = %w( __send__ __id__ send class inspect instance_eval instance_variables )
    instance_methods.each do |m|
      undef_method(m) unless keep_methods.include?(m)
    end
  end

  # A DSL class that allows options to be collected for a field
  # definition using a block and/or a hash.
  #  hash = { :colour => :red, :hue => 15 }
  #  collector = HashCollector.new( hash ) do |hc|
  #    hc.saturation = 17
  #    hc.opacity = 0.43
  #    hc.grooviness = 100
  #  end
  # or like this (without the block parameter)
  #  collector = HashCollector.new( hash ) do
  #    saturation 17
  #    opacity 0.43
  #    grooviness = 100
  #  end
  # either way, a call to collector.to_hash will result in
  #  { :hue=>15, :saturation=>17, :opacity=>0.43, :grooviness=>100, :colour=>:red }
  # and the following accessors will be added
  #  collector.hue
  #  collector.hue( some_value )
  #  collector.hue = some_value
  # for hue, saturation, opacity, grooviness and colour.
  class HashCollector < BlankSlate
    # Collect values from the hash and the block, using the collect method.
    def initialize( hash = {}, &block )
      @hash = hash || {}
      collect( &block )
    end
    
    # evaluate the block and collect options from args. Even if it's nil.
    def collect( args = {}, &block )
      @hash.merge!( args || {} )
      unless block.nil?
        if block.arity == -1
          instance_eval &block
        else
          yield self
        end
      end
    end
    
    # return a hash of the collected elements
    def to_hash
      @hash
    end
    
  protected
    
    # Modified from Jim Freeze's article.
    # For each symbol, add accessors to allow:
    #  instance.symbol as reader
    #  instance.symbol( value ) as writer
    #  instance.symbol = value as writer
    def self.dsl_accessor( *symbols )
      @stripper ||= /^([^\= ]+)\s*\=?\s*$/
      symbols.each do |sym|
        stripped = @stripper.match( sym.to_s )[1]
        line, st = __LINE__, <<-EOF
          def #{stripped}(*val)
            if val.empty?
              @hash[:#{stripped}]
            else
              @hash[:#{stripped}] = val.size == 1 ? val[0] : val
            end
          end
          
          def #{stripped}=(*val)
            @hash[:#{stripped}] = val.size == 1 ? val[0] : val
          end
        EOF
        class_eval st, __FILE__, line + 1
      end
    end
    
    # Do not allow accessors to be added dynamically. In other words,
    # a subclass like this
    #  class IndexCollector < HashCollector
    #    dsl_static
    #    dsl_accessor :row, :column
    #  end
    # will fail if used like this
    #  collector = IndexCollector.new( :row => 4, :column => 6 ) do
    #    other 'oops'
    #  end
    # because :other isn't added by dsl_accessor.
    def self.dsl_static
      @dynamic = false
    end
    
    # Allow accessors to be added dynamically, the default.
    def self.dsl_dynamic
      @dynamic = true
    end
    
    # Originally from Jim Freeze's article. Add the accessor methods if
    # they don't already exist, and if dsl_dynamic is in effect, which is
    # the default. If dsl_static is in effect, the normal method_missing
    # behaviour will be invoked.
    def method_missing(sym, *args)
      if self.class.dynamic?
        self.class.dsl_accessor sym
        send( sym, *args )
      else
        super
      end
    end
    
    def self.dynamic?
      @dynamic = true unless instance_variable_defined? '@dynamic'
      @dynamic
    end
    
  end

end
