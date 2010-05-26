require 'pathname'

desc "Enumerate all for an editor"
task :todos do |t|
  cmd = "find . -not -path '*svn*' -exec egrep -Hn 'TODO|FIXME|OPTIMI[ZS]E' {} \\;"
  rv = `#{cmd}`
  puts rv
end
