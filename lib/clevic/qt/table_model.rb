require 'Qt4'
require 'date'

require 'andand'

require 'qtext/flags.rb'
require 'qtext/extensions.rb'

require 'clevic/extensions.rb'
require 'clevic/qt/extensions.rb'
require 'clevic/model_column'

module Clevic

=begin rdoc
An instance of Clevic::TableModel is constructed by Clevic::ModelBuilder from the
UI definition in a Clevic::View, or from the default Clevic::View created by
including the Clevic::Record module in a ActiveRecord::Base or Sequel::Model subclass.
=end
class TableModel < Qt::AbstractTableModel
  include QtFlags
  include Clevic::TableModel
  
  signals(
    # index where error occurred, value, message
    'data_error(QModelIndex,QVariant,QString)'
  )
  
  def initialize( parent = nil )
    super
  end
  
  # add a new item, and set defaults from the Clevic::View
  def add_new_item_start( index )
    begin_insert_rows( Qt::ModelIndex.invalid, row_count, row_count )
  end
  
  def add_new_item_end( index )
    end_insert_rows
  end
  
  def remove_row_start( index )
    begin_remove_rows( Qt::ModelIndex.invalid, index, index )
  end
  
  def remove_row_end( index )
      end_remove_rows
  end
  
  # save the AR model at the given index, if it's dirty
  def update_vertical_header( index )
    emit headerDataChanged( Qt::Vertical, index.row, index.row )
  end
  
  def rowCount( parent = nil )
    collection.size
  end

  # Not looked up or aliased properly by Qt bindings
  def row_count
    collection.size
  end
  
  def columnCount( parent = nil )
    fields.size
  end
  
  # Not looked up or aliased properly by Qt bindings
  def column_count
    fields.size
  end
  
  def flags( model_index )
    retval = super
    
    # sometimes this actually happens. 
    # TODO probably a bug in the combo editor exit code
    return retval if model_index.column >= columnCount
    
    # TODO don't return IsEditable if the model is read-only
    if model_index.meta.type == :boolean
      retval = item_boolean_flags
    end
    
    unless model_index.field.read_only? || model_index.entity.andand.readonly? || read_only?
      retval |= qt_item_is_editable.to_i 
    end
    retval
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
  
  # Provide data to UI.
  def data( index, role = qt_display_role )
    #~ puts "data for index: #{index.inspect}, field #{index.field.attribute.inspect} and role: #{const_as_string role}"
    begin
      case role
        when qt_display_role
          # boolean values generally don't have text next to them in this context
          # check this explicitly to avoid fetching the entity from
          # the model's collection (and maybe db) when we
          # definitely don't need to
          unless index.meta.type == :boolean
            value = index.gui_value
            index.field.do_format( value ) unless value.nil?
          end
          
        when qt_edit_role
          # see comment for qt_display_role
          unless index.meta.type == :boolean
            value = index.gui_value
            index.field.do_edit_format( value ) unless value.nil?
          end
          
        when qt_checkstate_role
          if index.meta.type == :boolean
            index.gui_value ? qt_checked : qt_unchecked
          end
          
        when qt_text_alignment_role
          case index.field.alignment
            when :left; qt_alignleft
            when :right; qt_alignright
            when :centre; qt_aligncenter
            when :justified; qt_alignjustified
          end
        
        # just here to make debug output quieter
        when qt_size_hint_role;
        
        # show field with a red background if there's an error
        when qt_background_role
          index.field.background_for( index.entity ) || Qt::Color.new( 'red' ) if index.has_errors?
        
        when qt_font_role;
        
        when qt_foreground_role
          index.field.foreground_for( index.entity ) ||
          if index.field.read_only? || index.entity.andand.readonly? || read_only?
            Qt::Color.new( 'dimgray' )
          end
        
        when qt_decoration_role;
          index.field.decoration_for( index.entity )
        
        when qt_tooltip_role
          index.tooltip
        
        else
          puts "data index: #{index}, role: #{const_as_string(role)}" if $options[:debug]
          nil
      # return the variant
      end.to_variant
        
    rescue Exception => e
      puts "#{entity_view.class.name}.#{index.field.id}: #{index.inspect} for role: #{const_as_string role} #{value.inspect} #{index.entity.inspect}"
      puts e.message
      puts e.backtrace
      nil.to_variant
    end
  end

  # data sent from UI
  # return true if conversion from variant was successful,
  # or false if something went wrong.
  def setData( index, variant, role = qt_edit_role )
    if index.valid?
      case role
      when qt_edit_role
        # Don't allow the primary key to be changed
        return false if index.attribute == entity_class.primary_key.to_sym
        
        if ( index.column < 0 || index.column >= column_count )
          raise "invalid column #{index.column}" 
        end
        
        begin
          index.attribute_value =
          case
            when value.class.name == 'Qt::Date'
              Date.new( value.year, value.month, value.day )
              
            when value.class.name == 'Qt::Time'
              Time.new( value.hour, value.min, value.sec )
            
            else
              translate_to_db_object( index, variant.value )
          end
          
          # value conversion was successful
          data_changed( table_index )
          true
        rescue Exception => e
          puts e.backtrace.join( "\n" )
          puts e.message
          emit_data_error( index, variant, e.message )
          # value conversion was not successful
          false
        end

      when qt_checkstate_role
        if index.meta.type == :boolean
          index.entity.toggle( index.attribute )
          true
        else
          false
        end
      
      # user-defined role
      # TODO this only works with single-dotted paths
      when qt_paste_role
        if index.meta.type == :association
          field = index.field
          association_class = field.class_name.constantize
          candidates = association_class.find( :all, :conditions => [ "#{field.attribute_path[1]} = ?", variant.value ] )
          case candidates.size
            when 0; puts "No match for #{variant.value}"
            when 1; index.attribute_value = candidates[0]
            else; puts "Too many for #{variant.value}"
          end
        else
          index.attribute_value = variant.value
        end
        true
        
      else
        puts "role: #{role.inspect}"
        true
        
      end
    else
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
