require 'date'

require 'andand'

require 'clevic/extensions.rb'
require 'clevic/model_column'
require 'clevic/table_index'

module Clevic

class SwingTableIndex
  include TableIndex
  def initialize( model, row, column )
    @model, @row, @column = model, row, column
  end
  attr_accessor :model, :row, :column
end

=begin rdoc
An instance of Clevic::TableModel is constructed by Clevic::ModelBuilder from the
UI definition in a Clevic::View, or from the default Clevic::View created by
including the Clevic::Record module in a ActiveRecord::Base or Sequel::Model subclass.
=end
class TableModel < javax.swing.table.AbstractTableModel
  # TODO this arg is for the Qt bindings. Do we really need it?
  def initialize( qt_parent = nil )
    super()
  end
  
  # TODO not really sure what this do yet. Related to data_error signal from Qt
  def fireDataError( index, value, message )
  end
  
  # add a new item, and set defaults from the Clevic::View
  def add_new_item_start( index )
    raise "not implemented"
  end
  
  def add_new_item_end( index )
    raise "not implemented"
  end
  
  def remove_row_start( index )
    raise "not implemented"
  end
  
  def remove_row_end( index )
    raise "not implemented"
  end
  
  # save the AR model at the given index, if it's dirty
  def update_vertical_header( index )
    raise "not implemented"
  end
  
  # override TableModel method
  def getRowCount
    collection.size
  end

  # override TableModel method
  def getColumnCount
    fields.size
  end
  
  # override TableModel method
  def getColumnName( column_index )
    fields[column_index].label
  end
  
  # override TableModel method
  # TODO this should get values from Field
  def getColumnClass( column_index )
    java.lang.Object
  end
  
  # values for horizontal and vertical headers
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
    index = SwingTableIndex.new( self, row_index, column_index )
    !( index.field.read_only? || index.entity.andand.readonly? || read_only? )
  end
  
  # Provide data to UI
  def getValueAt( row_index, column_index )
    SwingTableIndex.new( self, row_index, column_index ).attribute_value
  end
  
  def setValueAt( value, row_index, column_index )
    index = SwingTableIndex.new( self, row_index, column_index )
    
    # Don't allow the primary key to be changed
    return false if index.attribute == entity_class.primary_key.to_sym
    
    # translate the value from the ui to something that
    # the DB entity will understand
    begin
      index.attribute_value =
      case
        when value.class.name == 'java.util.Date'
          Date.new( value.year, value.month, value.day )
        
        when value.class.name == 'java.util.Time'
          Time.new( value.hour, value.min, value.sec )
        
        else
          translate_to_db_object( index, value )
        
      end
      data_changed( index )
      # value conversion was successful
      true
    rescue Exception => e
      puts e.backtrace.join( "\n" )
      puts e.message
      emit_data_error( index, variant, e.message )
      # value conversion was not successful
      false
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
        if ( arg.respond_to?( :top_left ) && arg.respond_to?( :bottom_right ) ) || arg.is_a?( Qt::ItemSelectionRange )
          # object is a DataChange, or a SelectionRange
          top_left_index = create_index( arg.top_left.row, arg.top_left.column )
          bottom_right_index = create_index( arg.bottom_right.row, arg.bottom_right.column )
          emit dataChanged( top_left_index, bottom_right_index )
        else
          # assume it's a ModelIndex
          emit dataChanged( arg, arg )
        end
      
      when 2
        emit dataChanged( args.first, args.last )
      
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
