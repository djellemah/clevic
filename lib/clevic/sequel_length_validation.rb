require 'sequel'

=begin
This validates that strings going into varchar fields display meaningful
warnings instead of incomprenensible native RDBMS errors.
=end

class Sequel::Model
  def self.varchar_columns
    @varchar_columns ||= columns.select do |col|
      db_type = db_schema[col][:db_type]
      db_type =~ /var/ && db_type =~ /char/
    end
  end

  def validate
    super
    self.class.varchar_columns.each do |column|
      limit = self.class.meta[column].limit
      errors.add( column, "is longer than #{limit}" ) if self[column] && self[column].length > limit
    end
  end
end
