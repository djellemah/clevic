require 'clevic.rb'

# db connection options
Clevic::DbOptions.connect( $options ) do
  database :times
  adapter :sqlite3
end

require 'times_models.rb'

