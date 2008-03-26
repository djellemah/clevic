class EntryDelegate < Qt::ItemDelegate
  
  def initialize( parent, field_name, editor_class )
    super( parent )
    @field_name = field_name
    @editor_class = editor_class
  end
  
  def createEditor( parent_widget, style_option_view_item, model_index )
    @editor_class.new( parent_widget )
  end
  
  def setEditorData( editor, model_index )
    editor.value = model_index.gui_value
  end
  
  def setModelData( editor, abstract_item_model, model_index )
    model_index.gui_value = editor.value
    emit abstract_item_model.dataChanged( model_index, model_index )
  end
  
  def updateEditorGeometry( editor, style_option_view_item, model_index )
    # figure out where to put the editor widget, taking into
    # account the sizes of the headers
    rect = style_option_view_item.rect
    rect.set_width( editor.size_hint.width )
    editor.set_geometry( rect )
  end
end

=begin
Base class for other delegates using Combo boxes.

- emit focus out signals, because ComboBox stupidly doesn't.
=end
class ComboDelegate < Qt::ItemDelegate
  def initialize( parent )
    super
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
    @editor.show_popup
  end
  
  # returns true if the editor allows values outside of a predefined
  # range, false otherwise.
  def restricted?
    false
  end
  
  # Subclasses should override this to fill the combo box
  # list with values.
  def populate( editor, model_index )
    raise "subclass responsibility"
  end
  
  # This catches the event that begins the edit process.
  # Not used at the moment.
  def editorEvent ( event, model, style_option_view_item, model_index ) 
    super
  end
  
  # Override the Qt method. Create a ComboBox widget and fill it with the possible values.
  def createEditor( parent_widget, style_option_view_item, model_index )
    @editor = Qt::ComboBox.new( parent )
    
    # subclasses fill in the rest of the entries
    populate( @editor, model_index )
    
    # create a nil entry
    if ( @editor.find_data( nil.to_variant ) == -1 )
      @editor.add_item( '', nil.to_variant )
    end
    
    # allow prefix matching from the keyboard
    @editor.editable = true
    
    @editor
  end
  
  # Override the Qt::ItemDelegate method.
  def updateEditorGeometry( editor, style_option_view_item, model_index )
    # figure out where to put the editor widget, taking into
    # account the sizes of the headers
    rect = style_option_view_item.rect
    horizontal_header_rect = parent.horizontal_header.rect
    vertical_header_rect = parent.vertical_header.rect
    rect.translate( vertical_header_rect.width + 1, horizontal_header_rect.height + 1 )
    
    # ask the editor for how much space it wants, and set the editor
    # to that size when it displays in the table
    rect.set_width( editor.size_hint.width )
    editor.set_geometry( rect )
  end

  # Override the Qt method to send data to the editor from the model.
  def setEditorData( editor, model_index )
    editor.current_index = editor.find_data( model_index.attribute_value.to_variant )
    editor.line_edit.select_all
  end
  
  # This translates the text from the editor into something that is
  # stored in an underlying model. Intended to be overridden by subclasses.
  def translate_from_editor_text( editor, text )
    text
  end

  # Send the data from the editor to the model. The data will
  # be translated by translate_from_editor_text,
  def setModelData( editor, abstract_item_model, model_index )
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
    
    model_index.attribute_value = translate_from_editor_text( editor, value )
    
    emit abstract_item_model.dataChanged( model_index, model_index )
  end
end

# Provide a list of all values in this field,
# and allow new values to be entered.
class DistinctDelegate < ComboDelegate
  
  def initialize( parent, attribute, model_class, options )
    @ar_model = model_class
    @attribute = attribute
    @options = options
    @options[:conditions] ||= 'true'
    super( parent )
  end
  
  def populate( editor, model_index )
    # we only use the first column, so use the second
    # column to sort by, since SQL requires the order by clause
    # to be in the select list where distinct is involved
    rs = @ar_model.connection.execute <<-EOF
      select distinct #{@attribute.to_s}, lower(#{@attribute.to_s})
      from #{@ar_model.table_name}
      where #{@options[:conditions]}
      order by lower(#{@attribute.to_s})
    EOF
    rs.each do |row|
      editor.add_item( row[0], row[0].to_variant )
    end
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
  
  def populate( editor, model_index )
    # add set of all possible related entities
    @model_class.find( :all, @options ).each do |x|
      editor.add_item( x[@attribute_path], x.id.to_variant )
    end
    
    # always add the current selection, if it isn't already there
    # and it makes sense. This is to make sure that if the list
    # is filtered, we always have the current value if the filter
    # excludes it
    if !model_index.nil?
      item = model_index.attribute_value
      if item
        item_index = editor.find_data( item.id.to_variant )
        if item_index == -1
          editor.add_item( item[@attribute_path], item.id.to_variant )
        end
      end
    end
  end
  
  # send data to the editor
  def setEditorData( editor, model_index )
    editor.current_index = editor.find_data( model_index.attribute_value.id.to_variant )
    editor.line_edit.select_all
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
