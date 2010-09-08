#! /bin/bash
export RUBYLIB=`pwd`/lib:`pwd`/models
export CLASSPATH=$CLASSPATH:/usr/share/jdbc-postgresql/lib/jdbc-postgresql.jar:`pwd`/lib/clevic/swing/ui/dist/lib/swing-layout-1.0.3.jar
export PGHOST=groovious
jruby bin/clevic models/times_psql_models.rb
