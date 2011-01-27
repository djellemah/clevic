require 'active_support'
require 'active_support/core_ext/array/extract_options.rb'

module Sequel
  module Plugins
    module ArMethods
      # plugin :ar_methods calls this.
      # model is the model class. The rest is whatever options are
      # in the plugin call, possibility for
      #  plugin :ar_methods :override_sequel => true
      def self.configure(model, options = {})
        model.instance_eval do
          # store model-related stuff here
        end
      end
      
      module ClassMethods
        # Copy the necessary class instance variables to the subclass.
        def inherited(subclass)
          super
        end
        
        def lit_if_string( arg )
          if arg.is_a?( String )
            arg.lit
          else
            arg
          end
        end
        
        # Basically, we're translating from AR's hash options
        # to Sequel's method algebra, and returning the resulting
        # dataset.
        def translate( options )
          options.inject( dataset ) do |dataset, (key, value)|
            case key
              when :limit; dataset.limit( value, nil )
              when :offset
                # workaround for Sequel's refusal to do offset without limit
                dataset.limit( options[:limit] || :all, value )
              
              when :order
                orders = value.split(/, */ ).map do |x|
                  case x
                  when /(\w+) +(asc|desc)/i
                    $1.to_sym.send( $2 )
                    
                  when /(\w+)/i
                    x.to_sym
                  
                  else
                    raise "Don't know how to convert #{value} to Sequel. Use a Dataset instead."
                  end
                end
                puts "orders: #{orders.inspect}"
                dataset.order( *orders )
              
              when :conditions
                # this is most likely not adequate for all use cases
                # of the AR api
                dataset.filter( lit_if_string( value ) ) unless value.nil?
              
              when :include
                # this is the class to joing
                joined_class = eval( reflections[value][:class_name] )
                dataset.join_table(
                  :inner,
                  joined_class,
                  joined_class.primary_key => reflections[value][:key]
                ).select( table_name.* )
                
              else
                raise "#{key} not implemented"
            # make sure at least it's unchanged
            end || dataset
          end
          
          rescue Exception => e
            raise RuntimeError, "#{self.name} #{options.inspect} #{e.message}", caller(0)
        end
        
        def find_ar( *args )
          # copied from ActiveRecord::Base.find
          options = args.extract_options!
          #~ validate_find_options(options)
          #~ set_readonly_option!(options)
          
          case args.first
            when :first
              translate(options).first
              
            when :last
              translate(options).last
              
            when :all
              translate(options).all
              
            else
              if args.size == 1
                translate(options).filter( :id.qualify( table_name ) => args.first ).first
              else
                translate(options).filter( :id.qualify( table_name ) => args ).all
              end
          end
        end
        
        def count_ar( *args )
          options = args.extract_options!
          attribute = args.first
          
          dataset = translate( options )
          
          unless attribute.nil?
            dataset = dataset.select( attribute )
          end
          dataset.count
        end
        
      end
      
      module InstanceMethods
      end
    end
  end
end
