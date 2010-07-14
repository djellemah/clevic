require 'clevic.rb'

# db connection options
#~ Clevic::DbOptions.connect( $options ) do
  #~ database :times
  #~ adapter :sqlite
  #~ adapter 'jdbc/sqlite'
#~ end

$db = Sequel.sqlite File.dirname( __FILE__ ) + '/times'

require 'times_models.rb'

