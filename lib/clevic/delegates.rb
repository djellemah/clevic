require 'clevic/item_delegate.rb'

module Clevic

=begin rdoc
Base class for other delegates using Combo boxes. Emit focus out signals,
because ComboBox stupidly doesn't.

Generally these will be created using a ModelBuilder.
=end
class ComboDelegate < Clevic::ItemDelegate
  def initialize( parent )
    super
    @@active_record_options ||= [ :conditions, :class_name, :order ]
  end
  
  # Convert Qt:: constants from the integer value to a string value.
  def hint_string( hint )
    hs = String.new
    Qt::AbstractItemDelegate.constants.each do |x|
      hs = x if eval( "Qt::AbstractItemDelegate::#{x}.to_i" ) == hint.to_i
    end
    hs
  end
    
  def dump_editor_state( editor )
    if $options[:debug]
      puts "#{self.class.name}"
			puts "editor.completer.completion_count: #{editor.completer.completion_count}"
			puts "editor.completer.current_completion: #{editor.completer.current_completion}"
			puts "editor.find_text( editor.completer.current_completion ): #{editor.find_text( editor.completer.current_completion )}"
			puts "editor.current_text: #{editor.current_text}"
			puts "editor.count: #{editor.count}"
			puts "editor.completer.current_row: #{editor.completer.current_row}"
			puts "editor.item_data( editor.current_index ): #{editor.item_data( editor.current_index ).inspect}"
      puts
		end
  end
  
  # open the combo box, just like if f4 was pressed
  def full_edit
    if is_combo?( @editor )
      @editor.show_popup
    end
  end
  
  # returns true if the editor allows values outside of a predefined
  # range, false otherwise.
  def restricted?
    false
  end
  
  # TODO fetch this from the model definition
  def allow_null?
    true
  end
  
  # Subclasses should override this to fill the combo box
  # list with values.
  def populate( editor, model_index )
    raise "subclass responsibility"
  end
  
  # return true if this delegate needs a combo, false otherwise
  def needs_combo?
    raise "subclass responsibility"
  end

  def is_combo?( editor )
    editor.class == Qt::ComboBox
  end
  
  # return true if this field has no data (needs_combo? is false)
  # and is at the same time restricted (ie needs data from somewhere else)
  def empty_set?
    !needs_combo? && restricted?
  end
  
  # the message to display if the set is empty, and
  # the delegate is restricted to a predefined set.
  def empty_set_message
    raise "subclass responsibility"
  end
  
  # if this delegate has an empty set, return the message, otherwise
  # return nil.
  def if_empty_message
    if empty_set?
      empty_set_message
    end
  end
  
  def populate_current( editor, model_index )
    # add the current entry, if it isn't there already
    # TODO add it in the correct order
    if ( editor.find_data( model_index.gui_value.to_variant ) == -1 )
      editor.add_item( model_index.gui_value, model_index.gui_value.to_variant )
    end
  end
  
  # Override the Qt method. Create a ComboBox widget and fill it with the possible values.
  def createEditor( parent_widget, style_option_view_item, model_index )
    if needs_combo?
      @editor = Qt::ComboBox.new( parent_widget )
      
      # subclasses fill in the rest of the entries
      populate( @editor, model_index )
      
      # add the current item, if it isn't there already
      populate_current( @editor, model_index )
      
      # create a nil entry
      if allow_null?
        if ( @editor.find_data( nil.to_variant ) == -1 )
          @editor.add_item( '', nil.to_variant )
        end
      end
      
      # allow prefix matching from the keyboard
      @editor.editable = true
      
      # don't insert if restricted
      @editor.insert_policy = Qt::ComboBox::NoInsert if restricted?
    else
      @editor =
      if restricted?
        emit parent.status_text( empty_set_message )
        nil
      else
        Qt::LineEdit.new( model_index.gui_value, parent_widget )
      end
    end
    @editor
  end
  
  # Override the Qt::ItemDelegate method.
  def updateEditorGeometry( editor, style_option_view_item, model_index )
    rect = style_option_view_item.rect
    
    # ask the editor for how much space it wants, and set the editor
    # to that size when it displays in the table
    rect.set_width( [editor.size_hint.width,rect.width].max ) if is_combo?( editor )
    editor.set_geometry( rect )
  end

  # Override the Qt method to send data to the editor from the model.
  def setEditorData( editor, model_index )
    if is_combo?( editor )
      editor.current_index = editor.find_data( model_index.attribute_value.to_variant )
      editor.line_edit.select_all if editor.editable
    else
      editor.text = model_index.gui_value
    end
  end
  
  # This translates the text from the editor into something that is
  # stored in an underlying model. Intended to be overridden by subclasses.
  def translate_from_editor_text( editor, text )
    index = editor.find_text( text )
    if index == -1
      text unless restricted?
    else
      editor.item_data( index ).value
    end
  end

  # Send the data from the editor to the model. The data will
  # be translated by translate_from_editor_text,
  def setModelData( editor, abstract_item_model, model_index )
    if is_combo?( editor )
      dump_editor_state( editor )
      value = 
      if editor.completer.current_row == -1
        # item doesn't exist in the list, add it if not restricted
        editor.current_text unless restricted?
      elsif editor.completer.completion_count == editor.count
        # selection from drop down. if it's empty, we want a nil
        editor.current_text
      else
        # there is a matching completion, so use it
        editor.completer.current_completion
      end
      
      if value != nil
        model_index.attribute_value = translate_from_editor_text( editor, value )
      end
      
    else
      model_index.gui_value = editor.text
    end
    emit abstract_item_model.dataChanged( model_index, model_index )
  end

protected

  # given a hash of options, return only those
  # which are applicable to a ActiveRecord::Base.find
  # method call
  def collect_finder_options( options )
    new_options = {}
    options.each do |key,value|
      if @@active_record_options.include?( key )
        new_options[key] = value
      end
    end
    new_options
  end

end

# Provide a list of all values in this field,
# and allow new values to be entered.
# :frequency can be set as an option. Boolean. If it's true
# the options are sorted in order of most frequently used first.
class DistinctDelegate < ComboDelegate
  
  def initialize( parent, attribute, model_class, options )
    @ar_model = model_class
    @attribute = attribute
    @options = options
    # hackery for amateur query building in populate
    @options[:conditions] ||= 'true'
    super( parent )
  end
  
  def needs_combo?
    # works except when there is a '' in the column
    @ar_model.count( @attribute, collect_finder_options( @options ) ) > 0
  end
  
  def populate_current( editor, model_index )
    # already done in the SQL query in populate, so don't even check
  end
  
  def query_order_description( conn, model_index )
    <<-EOF
      select distinct #{@attribute.to_s}, lower(#{@attribute.to_s})
      from #{@ar_model.table_name}
      where (#{@options[:conditions]})
      or #{conn.quote_column_name( @attribute.to_s )} = #{conn.quote( model_index.attribute_value )}
      order by lower(#{@attribute.to_s})
    EOF
  end
  
  def query_order_frequency( conn, model_index )
    <<-EOF
      select distinct #{@attribute.to_s}, count(#{@attribute.to_s})
      from #{@ar_model.table_name}
      where (#{@options[:conditions]})
      or #{conn.quote_column_name( @attribute.to_s )} = #{conn.quote( model_index.attribute_value )}
      group by #{@attribute.to_s}
      order by count(#{@attribute.to_s}) desc
    EOF
  end
  
  def populate( editor, model_index )
    # we only use the first column, so use the second
    # column to sort by, since SQL requires the order by clause
    # to be in the select list where distinct is involved
    conn = @ar_model.connection
    query =
    if @options[:frequency]
      query_order_frequency( conn, model_index )
    else
      query_order_description( conn, model_index )
    end
    rs = conn.execute( query )
    rs.each do |row|
      puts "adding: #{row[0]}"
      editor.add_item( row[0], row[0].to_variant )
    end
  end
  
  def translate_from_editor_text( editor, text )
    text
  end
end

# A Combo box which only allows a restricted set of value to be entered.
class RestrictedDelegate < ComboDelegate
  # options must contain a :set => [ ... ] to specify the set of values.
  def initialize( parent, attribute, model_class, options )
    raise "RestrictedDelegate must have a :set in options" unless options.has_key?( :set )
    @ar_model = model_class
    @attribute = attribute
    @options = options
    @set = options[:set]
    super( parent )
  end
  
  def needs_combo?
    true
  end
  
  def restricted?
    true
  end
  
  def populate( editor, model_index )
    @set.each do |item|
      editor.add_item( item, item.to_variant )
    end
  end
end

# Edit a relation from an id and display a list of relevant entries.
#
# attribute_path is the full dotted path to get from the entity in the
# model to the values displayed in the combo box.
# 
# The ids of the ActiveRecord models are stored in the item data
# and the item text is fetched from them using attribute_path.
class RelationalDelegate < ComboDelegate

  def initialize( parent, attribute_path, options )
    @model_class = ( options[:class_name] || attribute_path[0].to_s.classify ).constantize
    @attribute_path = attribute_path[1..-1].join('.')
    @options = options.clone
    [ :class_name, :sample, :format ].each {|x| @options.delete x }
    super( parent )
  end
  
  def needs_combo?
    @model_class.count( :conditions => @options[:conditions] ) > 0
  end
  
  def empty_set_message
    "There must be records in #{@model_class.name.humanize} for this field to be editable."
  end
  
  # add the current item, unless it's already in the combo data
  def populate_current( editor, model_index )
    # always add the current selection, if it isn't already there
    # and it makes sense. This is to make sure that if the list
    # is filtered, we always have the current value if the filter
    # excludes it
    unless model_index.nil?
      item = model_index.attribute_value
      if item
        item_index = editor.find_data( item.id.to_variant )
        if item_index == -1
          editor.add_item( item[@attribute_path], item.id.to_variant )
        end
      end
    end
  end

  def populate( editor, model_index )
    # add set of all possible related entities
    @model_class.find( :all, collect_finder_options( @options ) ).each do |x|
      editor.add_item( x[@attribute_path], x.id.to_variant )
    end
  end
  
  # send data to the editor
  def setEditorData( editor, model_index )
    if is_combo?( editor )
      editor.current_index = editor.find_data( model_index.attribute_value.id.to_variant )
      editor.line_edit.select_all
    end
  end
  
  # don't allow new values
  def restricted?
    true
  end
  
  # return an AR entity object
  def translate_from_editor_text( editor, text )
    item_index = editor.find_text( text )
    
    # fetch record id from editor item_data
    item_data = editor.item_data( item_index )
    if item_data.valid?
      # get the entity it refers to, if there is one
      # use find_by_id so that if it's not found, nil will
      # be returned
      @model_class.find_by_id( item_data.to_int )
    end
  end
  
end

end
