= clevic

http://www.semiosix.com/clevic

== DESCRIPTION:

Framework and Qt Model/View GUI for data capture and editing of tables in a pre-existing
relational DBMS. Uses ActiveRecord for data access.

There is a mild focus on reducing keystrokes for repetive data capture, so
it provides
nice keyboard shortcuts for all sorts of things. Model (table) objects
are extensible to allow for model (table) specific cleverness, like
auto-filling-in of fields.

== FEATURES/PROBLEMS:

* uses ActiveRecord for data access. Does *not* use the Qt SQL models.
* sensible caching to handle large data sets without unnecessary memory usage
* in-place Combo boxes for related table and foreign keys
* distinct combo boxes to list previous values for a field
* cut and paste in CSV format
* sortable by row headers
* color highlighting of fields and records on definable criteria
* extensions to various Qt classes to make db programming easier

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
Start with Browser and EntryBuilder.

== SYNOPSIS:

	clevic model_definition_file

== REQUIREMENTS:

* ruby-qt4
* bsearch
* active_record/dirty

== INSTALL:

	sudo gem install

== LICENSE:

(The MIT License)

Copyright (c) 2008 FIX

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
