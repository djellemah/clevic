module Clevic
  # Provide some SQL dialect differences that aren't in ActiveRecord. Including
  # class must respond to entity_class.
  module SqlDialects
    def adapter_name
      connection.adapter_name
    end
    
    def connection
      entity_class.connection
    end
    
    # return a string containing the correct
    # boolean value depending on the DB adapter
    # because Postgres wants real true and false in complex statements, not 't' and 'f'
    def sql_boolean( value )
      case adapter_name
        when 'PostgreSQL'
          value ? 'true' : 'false'
        else
          value ? connection.quoted_true : connection.quoted_false
      end
    end
    
    # return a case-insensitive like operator
    def like_operator
      case adapter_name
        when 'PostgreSQL'; 'ilike'
        else; 'like'
      end
    end
  end
end
