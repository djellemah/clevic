require 'clevic.rb'

# db connection options
$options ||= {}
Clevic::DbOptions.connect( $options ) do
  # use a different db for testing, so real data doesn't get broken.
  # unless the command-line option is specified
  if $options[:database].blank?
    database( debug? ? :times_test : :times )
  else
    database $options[:database]
  end
  # for AR
  #~ adapter :postgresql
  # for Sequel
  adapter :postgres
  username 'times' if $options[:username].blank?
end

require 'times_models.rb'
