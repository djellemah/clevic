# remove hoe documentation task
Rake::Task['docs'].clear

# make this respond to docs, so it fits in with the rest of the build
desc 'Generate docs using rdoc 1, not rdoc 2 which messes things up quite badly'
task :docs do |t|
  `rdoc -SHN -A property=P -m README.txt README.txt lib models/examples.rb History.txt TODO`
end
