require 'clevic/qt/delegate.rb'
require 'clevic/qt/qt_combo_box.rb'

module Clevic

=begin rdoc
Base class for other delegates using Combo boxes. Emit focus out signals,
because ComboBox stupidly doesn't.

Generally these will be created using a Clevic::ModelBuilder.
=end
class ComboDelegate < Clevic::Delegate
  # Convert Qt:: constants from the integer value to a string value.
  # TODO this really shouldn't be here. qtext, or extensions.rb
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
    editor.show_popup if is_combo?( editor )
  end
  
  def is_combo?( editor )
    editor.is_a?( Qt::ComboBox )
  end
  
  def create_combo_box( *args )
    Qt::ComboBox.new( parent ).tap do |combo|
      # all combos are editable so that prefix matching will work
      combo.editable = true
    end
  end
  
  # Override the Qt method. Create a ComboBox widget and fill it with the possible values.
  def createEditor( parent_widget, style_option_view_item, model_index )
    self.parent = parent_widget
    self.entity = model_index.entity
    init_component( parent_widget, style_option_view_item, model_index )
    editor.delegate = self
    editor
  end

  def line_editor( edit_value )
    @line_editor ||= Qt::LineEdit.new( edit_value, parent )
  end
  
  def framework_setup( *args )
    # don't need to do anything here
    # might need to once prefix-matching is implemented
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
      editor.text = model_index.edit_value
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
      model_index.attribute_value = editor.text
    end
    abstract_item_model.data_changed( model_index )
  end

end

end

require 'clevic/delegates/combo_delegate'
