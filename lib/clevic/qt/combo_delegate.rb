require 'clevic/qt/delegate.rb'

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
    if ( editor.find_data( model_index.display_value.to_variant ) == -1 )
      editor.add_item( model_index.display_value, model_index.display_value.to_variant )
    end
  end

  def add_nil_item( editor )
    if ( editor.find_data( nil.to_variant ) == -1 )
      editor.add_item( '', nil.to_variant )
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
      add_nil_item( @editor ) if allow_null?
      
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
        Qt::LineEdit.new( model_index.edit_value, parent_widget )
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
