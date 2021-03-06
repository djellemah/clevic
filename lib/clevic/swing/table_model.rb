require 'date'

require 'fastandand'

require 'clevic/extensions.rb'
require 'clevic/swing/extensions.rb'
require 'clevic/model_column.rb'
require 'clevic/table_index.rb'
require 'clevic/emitter.rb'

require 'clevic/swing/swing_table_index.rb'

module Clevic

=begin rdoc
An instance of Clevic::TableModel is constructed by Clevic::ModelBuilder from the
UI definition in a Clevic::View, or from the default Clevic::View created by
including the Clevic::Record module in a Sequel::Model subclass.
=end
class TableModel < javax.swing.table.AbstractTableModel
  include Emitter

  # index, value, message
  emitter :data_error

  def initialize
    super()
  end

  def create_index( row, column )
    SwingTableIndex.new( self, row, column )
  end

  # add a new item, and set defaults from the Clevic::View
  def add_new_item_start
    # don't need to do anything
  end

  def add_new_item_end
    fireTableRowsInserted( collection.size, collection.size )
  end

  def remove_notify( rows, &block )
    # no need to do anything before removing rows
    yield
    # tell the views
    fireTableRowsDeleted( rows.first, rows.last )
  end

  # Tell the UI we had a major data change
  def reset
    # could also use fireTableStructureChanged(), but it doesn't seem necessary
    fireTableDataChanged
  end

  # override TableModel method
  def getRowCount
    collection.size
  end

  # make it ruby-nice
  alias_method :row_count, :getRowCount

  # override TableModel method
  def getColumnCount
    fields.size
  end

  # make it ruby-nice
  alias_method :column_count, :getColumnCount

  # override TableModel method
  def getColumnName( column_index )
    fields[column_index].label
  end

  # override TableModel method
  def getColumnClass( column_index )
    if fields[column_index].meta.type == :boolean || fields[column_index].delegate.is_a?( BooleanDelegate )
      # easiest way to display a checkbox
      java.lang.Boolean
    else
      # This will be a treated as a String value
      java.lang.Object
    end
  end

  def isCellEditable( row_index, column_index )
    index = create_index( row_index, column_index )
    !( index.field.read_only? || index.entity.andand.readonly? || read_only? )
  end

  def valuer_for( index )
    case
    # pull values from entity at index
    when index.field.entity_class == entity_class
      index

    # pull values from the Clevic::View class
    when entity_view.class.ancestors.include?( Clevic::View )
      #~ entity_view.entity = index.entity
      FieldValuer.valuer( index.field, entity_view )

    else
      raise "No valuer for #{index.inspect}"
    end
  end

  # Provide raw value to renderers
  def getValueAt( row_index, column_index )
    index = create_index( row_index, column_index )

    #~ valuer = valuer_for( index )
    valuer = index

    if index.field.delegate.native
      valuer.display_value
    else
      valuer.attribute_value
    end

  rescue
    puts $!.inspect
    puts $!.backtrace
    nil
  end

  def setValueAt( value, row_index, column_index )
    index = create_index( row_index, column_index )
    #~ puts "setting index: #{index.inspect} to #{value.inspect}"
    #~ valuer = valuer_for( index )
    valuer = index

    # Don't allow the primary key to be changed
    return if index.attribute == entity_class.primary_key.to_sym

    # translate the value from the ui to something that
    # the DB entity will understand
    begin
      if value.is_a?( java.util.Date )
        valuer.attribute_value =
        case value
        # more specific descendant first
        when java.util.Time
          Time.new( value.hour, value.min, value.sec )

        when java.util.Date
          Date.new( value.year, value.month, value.day )

        else
          raise "don't know how to convert a #{value.class.name}:#{value.inspect}"
        end
      else
        valuer.edit_value = value
      end

      valuer.entity.save

      data_changed( index )
    rescue Exception => e
      puts "#{__FILE__}:#{__LINE__}:e.message: #{e.message}"
      puts e.backtrace
      emit_data_error( index, value, e.message )
    end
  end

  # A rubyish way of doing dataChanged
  # - if args has one element, it's either a single ModelIndex
  #   or something that understands top_left and bottom_right. These
  #   will be turned into a ModelIndex by calling create_index
  # - if args has two element, assume it's a two ModelIndex instances
  # - otherwise create a new DataChange and pass it to the block.
  def data_changed( *args, &block )
    case args.size
      when 1
        arg = args.first
        if ( arg.respond_to?( :top_left ) && arg.respond_to?( :bottom_right ) )
          # object is a DataChange
          fireTableRowsUpdated( arg.top_left.row, arg.bottom_right.row )
        else
          # assume it's a ModelIndex, so one cell was updated
          fireTableCellUpdated( arg.row, arg.column )
        end

      when 2
        fireTableRowsUpdated( args.first.row, args.last.row )

      else
        unless block.nil?
          change = DataChange.new
          block.call( change )
          # recursive call
          data_changed( change )
        end
    end
  end

end

end #module
