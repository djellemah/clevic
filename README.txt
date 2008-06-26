= clevic

http://www.rubyforge.org/clevic

== DESCRIPTION:

Database framework and Qt Model/View GUI for data capture and
editing of tables in a pre-existing relational DBMS. Thanks to ActiveRecord,
Postgresql, Mysql and so on are supported. Has only been tested with Postgres.

There is a mild focus on reducing keystrokes for repetitive data capture,
so it provides
nice keyboard shortcuts for all sorts of things. Model (table) objects
are extensible to allow for model (table) specific cleverness, like
auto-filling-in of fields.

== FEATURES:

* Filter by current field.
* search by field contents.
* uses ActiveRecord for data access. Does *not* use the Qt SQL models.
* sensible caching to handle large data sets without unnecessary memory and cpu usage
* in-place Combo boxes for related table and foreign keys
* distinct combo boxes to list previous values for a field
* cut and paste in CSV format
* sortable by row headers (not yet)
* color highlighting of fields and records on definable criteria (not yet).
* extensions to various Qt classes to make db programming easier.
* leverages SQL whenever possible to handle large datasets, sorting, filtering
  etc. So it's probably not suitable for talking to a remote db across a slow link.

=== Shortcuts:

* Ctrl-' for ditto (copy value from previous record)
* Ctrl-; for insert current date
* Ctrl-] for copy previous record, one field right
* Ctrl-[ for copy previous record, one field left
* Ctrl-f to find a record
* Ctrl-l to filter by current selection
* cursor keys for movement

=== Model definition:

Right now, models must be defined in Ruby. The framework provides
an easy Rails-migrations-like syntax for that.
Start with account_models.rb and times_models.rb, with associated SQL
schemas in the sql subdirectory. For implementation and more extensive
comments, see Browser and EntryBuilder.

== PROBLEMS:

See TODO file.

== SYNOPSIS:

	clevic model_definition_file

== REQUIREMENTS:

* fastercsv
* ruby-qt4
* bsearch
* active_record
* active_record/dirty (included)
* db driver (ie postgres-pr)
* rdbms (ie postgres)

== INSTALL:

	sudo gem install

== THANKS:

* Michelle Riley for help debugging the windows gem

== LICENSE:

(The GPL-2 License)

Copyright (C) 2008 John Anderson

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU Library General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU Library General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
