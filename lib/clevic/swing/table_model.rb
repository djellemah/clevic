require 'date'

require 'andand'

require 'clevic/extensions.rb'
require 'clevic/swing/extensions.rb'
require 'clevic/model_column'
require 'clevic/table_index'

require 'clevic/swing/swing_table_index.rb'

module Clevic

=begin rdoc
An instance of Clevic::TableModel is constructed by Clevic::ModelBuilder from the
UI definition in a Clevic::View, or from the default Clevic::View created by
including the Clevic::Record module in a ActiveRecord::Base or Sequel::Model subclass.
=end
class TableModel < javax.swing.table.AbstractTableModel
  def initialize
    super()
  end
  
  def create_index( row, column )
    SwingTableIndex.new( self, row, column )
  end
  
  # TODO not really sure what this do yet. Related to data_error signal from Qt
  def fireDataError( index, value, message )
    puts "fireDataError: #{index.inspect}, #{value.inspect}, #{message}"
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
  
  def update_vertical_header( index )
    puts "#{__FILE__}:#{__LINE__}: TODO update_vertical_header not implemented"
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
    case fields[column_index].meta.type
      # easiest way to display a checkbox
      when :boolean; java.lang.Boolean
      # This will be a treated as a String value
      else java.lang.Object
    end
  end
  
  # TODO use coloring code once I've done vertical header
  def headerData( section, orientation, role )
    value = 
    case role
      when qt_display_role
        case orientation
          when Qt::Horizontal
            labels[section]
          when Qt::Vertical
            # don't force a fetch from the db
            if collection.cached_at?( section )
              collection[section].id
            else
              section
            end
        end
        
      when qt_text_alignment_role
        case orientation
          when Qt::Vertical
            Qt::AlignRight | Qt::AlignVCenter
        end
          
      when Qt::SizeHintRole
        # anything other than nil here makes the headers disappear.
        nil
        
      when qt_tooltip_role
        case orientation
          when Qt::Horizontal
            fields[section].tooltip
            
          when Qt::Vertical
            case
              when !collection[section].errors.empty?
                'Invalid data'
              when collection[section].changed?
                'Unsaved changes'
            end
        end
        
      when qt_background_role
        if orientation == Qt::Vertical
          item = collection[section]
          case
            when !item.errors.empty?
              Qt::Color.new( 'orange' )
            when item.changed?
              Qt::Color.new( 'yellow' )
          end
        end
        
      else
        #~ puts "headerData section: #{section}, role: #{const_as_string(role)}" if $options[:debug]
        nil
    end
    
    return value.to_variant
  end
  
  def isCellEditable( row_index, column_index )
    index = create_index( row_index, column_index )
    !( index.field.read_only? || index.entity.andand.readonly? || read_only? )
  end
  
  # Provide data to UI
  def getValueAt( row_index, column_index )
    create_index( row_index, column_index ).attribute_value
  rescue
    puts $!.inspect
    nil
  end
  
  def setValueAt( value, row_index, column_index )
    index = create_index( row_index, column_index )
    puts "setting index: #{index.inspect} to #{value.inspect}"
    
    # Don't allow the primary key to be changed
    return if index.attribute == entity_class.primary_key.to_sym
    
    # translate the value from the ui to something that
    # the DB entity will understand
    begin
      if value.is_a?( java.util.Date )
        index.attribute_value =
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
        index.edit_value = value
      end
      
      puts "NOT SAVING YET index: #{index.inspect}"
      data_changed( index )
    rescue Exception => e
      puts e.backtrace
      puts e.message
      fireDataError( index, value, e.message )
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
