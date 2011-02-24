= clevic

http://clevic.rubyforge.org

== DESCRIPTION:

Database framework and Model/View GUI for data capture and
editing of tables in a pre-existing relational DBMS. Works with Qt
and Java Swing. Uses SQL to do sorting and filtering wherever possible.

Based on the idea of a Field, which contains information to display
a db field in a UI of some kind. This includes display formatting, edit
formatting, edit parsing, sets of values for eg foreign keys.
And lots more.

Using Sequel means Clevic works with Postgresql, Mysql and so on. It's been
tested with Postgres and sqlite.

Using Qt and Swing means it runs on Linux, Windows and OSX. The Qt
code is thoroughly tested in Linux, slightly tested in Windows and OSX. Swing 
is tested in Linux and OSX.

== FEATURES:

=== User Interface

* edit data in a table
* in-place combo boxes for choosing values from related tables (foreign keys)
* distinct combo boxes to list previous values for a field
* display read-only fields from related tables
* Recursive Filter by current field
* search by field contents
* cut and paste in CSV and paste from HTML in the Java framework.

=== Shortcuts:

* Ctrl-' for ditto (copy value from previous record)
* Ctrl-; for insert current date
* Ctrl-] for copy previous record, one field right
* Ctrl-[ for copy previous record, one field left
* Ctrl-f to find a record
* Ctrl-l to add a filter (by current selection)
* Ctrl-k to remove a filter
* cursor keys, PgUp PgDown etc for movement

=== Model definition:

Models and their UI representation must be defined in Ruby. A descendant of Sequel::Model
that includes the Clevic::Record module will provide a minimally functional UI.

Beyond that, the framework provides a DSL for defining more complex and useful behaviour
(see Clevic::ModelBuilder).

=== Examples

In the models/ subdirectory, start with minimal_models.rb. account_models.rb 
and times_models.rb provide definitions for real-world examples. Associated 
SQL schemas are in the sql subdirectory. For implementation and more extensive 
comments, see Clevic::ModelBuilder.

=== Framework

* uses Sequel for data access.
* can use blocks to format values for particular fields.
* sensible caching to handle large data sets without unnecessary memory and cpu usage
* extensions to various Qt classes to make db programming easier.
* leverages SQL whenever possible to handle large datasets, sorting, filtering
  etc. So it's probably not suitable for talking to a remote db across a slow link.

== PROBLEMS:

There are some tests for algorithmic code, but Clevic needs a comprehensive testing framework.

== SYNOPSIS:

	clevic [ --qt | --swing ] model_definition_file.rb
	
== REQUIREMENTS:

=== Gems
* Sequel
* fastercsv
* qtext
* hashery (for ruby-1.8.x)
* qtbindings
* gather

=== Libraries
* qtruby4 >= 2.0.3
* bsearch (http://0xcc.net/ruby-bsearch)
* db driver (ie pg)
* rdbms (ie postgres)

== INSTALL:

	Get bsearch from http://0xcc.net/ruby-bsearch
	
	Install qt bindings from https://github.com/ryanmelt/qtbindings
	
	sudo gem install

== THANKS:

* Michelle Riley for help debugging under windows
* Jacob Buys for pointing out the qtbindings gem

== LICENSE:

(The GPL-2 License)

Copyright (C) 2008-2011 John Anderson

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
