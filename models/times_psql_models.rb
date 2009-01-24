require 'clevic.rb'

# db connection options
$options ||= {}
Clevic::DbOptions.connect( $options ) do
  # use a different db for testing, so real data doesn't get broken.
  # unless the command-line option is specified
  if $options[:database].nil? || $options[:database].empty?
    database( debug? ? :times_test : :times )
  else
    database $options[:database]
  end
  adapter :postgresql
  username 'times' unless $options[:username]
end

require 'times_models.rb'
