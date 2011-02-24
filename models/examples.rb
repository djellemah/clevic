module Clevic

=begin rdoc

See also Clevic::ModelBuilder and Clevic::Field

== Examples:
* No-frills models
* Simple Accounting database
* Read-only based on SQL views
* Not yet working multi-valued fields
* Work hours database
* Work hours database using Sqlite
* Work hours database using Postgres
* Work hours database using ActiveRecord style models

==No-frills models
 :include:models/minimal_models.rb

==Simple Accounting database
 :include:models/accounts_models.rb

== Read-only based on SQL views
 :include:models/values_models.rb

== Not yet working multi-valued fields
 :include:models/contacts.rb

== Work hours database
 :include:models/times_models.rb

== Work hours database using Sqlite
 :include:models/times_sqlite_models.rb
 
== Work hours database using Postgres
 :include:models/times_psql_models.rb
 
== Work hours database using ActiveRecord style models
 :include:models/times_ar_style_models.rb

=end
class Examples
end

end
