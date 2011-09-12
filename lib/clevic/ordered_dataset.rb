module Clevic

  # Provides a nice way of getting to Sequel::Dataset's
  # opts[:order] information
  #
  # Including class must call dataset= before calling order_attributes
  module OrderedDataset

    # returns a collection of [ attribute, (1|-1) ]
    # where 1 is forward/asc (>) and -1 is backward/desc (<)
    def order_attributes
      if @order_attributes.nil?
        @order_attributes =
        dataset.opts[:order].map do |order_expr|
          case order_expr
          when Symbol
            [ order_expr, 1 ]

          when Sequel::SQL::OrderedExpression
            [ order_expr.expression, order_expr.descending ? -1 : 1 ]

          else
            raise "unknown order_expr: #{order_expr.inspect}"
          end
        end
      end
      @order_attributes
    end

    attr_reader :dataset

    # Set default dataset ordering to primary key if it doesn't
    # already have an order.
    def dataset=( other )
      @dataset =
      if other.opts[:order].nil?
        other.order( other.model.primary_key )
      else
        other
      end
    end

  end

end
