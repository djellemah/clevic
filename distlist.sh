#! /bin/bash
export RUBYLIB=`pwd`/lib:`pwd`/models
export CLASSPATH=$CLASSPATH:/usr/share/jdbc-postgresql/lib/jdbc-postgresql.jar
export PGHOST=groovious
jruby bin/clevic models/times_psql_models.rb
