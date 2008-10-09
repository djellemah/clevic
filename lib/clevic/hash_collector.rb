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
    
    # Originally from Jim Freeze's article. Add the accessor methods if
    # they don't already exist.
    def method_missing(sym, *args)
      self.class.dsl_accessor sym
      send(sym, *args)
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
  end

end
