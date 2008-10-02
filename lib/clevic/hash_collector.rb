module Clevic

  class BlankSlate
    keep_methods = %w( __send__ __id__ send class inspect instance_eval instance_variables )
    instance_methods.each do |m|
      undef_method(m) unless keep_methods.include?(m)
    end
  end

  # a basic DSL class that allows options to be collected for a field
  # definition using a block rather than a hash. See Clevic::ModelBuilder for
  # an example.
  class HashCollector < BlankSlate
    def initialize( hash = {}, &block )
      @hash = hash
      collect( &block )
    end
    
    # modified from Jim Freeze's article
    def self.dsl_accessor(*symbols)
      symbols.each do |sym|
        line, st = __LINE__, <<-EOF
          def #{sym}(*val)
            if val.empty?
              @hash[#{sym.to_sym.inspect}]
            else
              @hash[#{sym.to_sym.inspect}] = val.size == 1 ? val[0] : val
            end
          end

          def #{sym}=(*val)
            @hash[#{sym.to_sym.inspect}] = val.size == 1 ? val[0] : val
          end
        EOF
        class_eval st, __FILE__, line + 1
      end
    end
    
    # originally from Jim Freeze's article
    def method_missing(sym, *args)
      self.class.dsl_accessor sym
      send(sym, *args)
    end
    
    # evaluate the block and collect options
    def collect( &block )
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
