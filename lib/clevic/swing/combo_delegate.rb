require 'clevic/swing/delegate'

module Clevic

=begin rdoc
Base class for other delegates using Combo boxes.

Generally these will be created using a Clevic::ModelBuilder.
=end
class ComboDelegate < Delegate
  def initialize( field )
    super( field )
  end
  
  # this is the GUI component / widget that is displayed
  attr_reader :editor
  
  def new_combo_box
    # renderer should call field.transform_attribute( item )
    javax.swing.JComboBox.new.tap do |combo|
      @original_renderer = combo.renderer
      combo.renderer = self
    end
  end
  
  include javax.swing.ListCellRenderer
  
  # return the component to render the values in the list
  # we just transform the value, and pass it to the
  # pre-existing renderer for the combo.
  def getListCellRendererComponent(jlist, value, index, selected, cell_has_focus)
    display_value = field.transform_attribute( value )
    @original_renderer.getListCellRendererComponent(jlist, display_value, index, selected, cell_has_focus)
  end
  
  def new_line_editor( value )
    javax.swing.JTextField.new( value )
  end
  
  def configure_prefix
    puts "TODO: implement ComboDelegate#configure_prefix"
  end
  
  def configure_editable
    editor.editable = !restricted?
  end
  
  # Create a GUI widget and fill it with the possible values.
  def component( entity )
    if needs_combo?
      @editor = new_combo_box
      
      # add the current item, if it isn't there already
      populate_current( entity )
      
      # subclasses fill in the rest of the entries
      populate( entity )
      
      # create a nil entry
      add_nil_item if allow_null?
      
      # allow prefix matching from the keyboard
      configure_prefix
      
      # don't insert if restricted
      configure_editable
      
      # set the correct value in the list
      select_current( entity )
    else
      @editor =
      if restricted?
        emit parent.status_text( empty_set_message )
        nil
      else
        new_line_editor( field.edit_format( entity ) )
      end
    end
    editor
  end
  
  # open the combo box, just like if f4 was pressed
  def full_edit
    editor.show_popup if is_combo?
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
  def populate( entity )
    raise "subclass responsibility"
  end
  
  # return true if this delegate needs a combo, false otherwise
  def needs_combo?
    raise "subclass responsibility"
  end

  def is_combo?
    editor.is_a?( javax.swing.JComboBox )
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
    empty_set_message if empty_set?
  end
  
  # add the current item, unless it's already in the combo data
  def populate_current( entity )
    # always add the current selection, if it isn't already there
    # and it makes sense. This is to make sure that if the list
    # is filtered, we always have the current value if the filter
    # excludes it
    item = field.attribute_value_for( entity )
    editor << item if item && !editor.include?( item )
  end

  def add_nil_item
    editor << nil unless editor.include?( nil )
  end
  
  def select_current( entity )
    editor.selected_item = field.attribute_value_for( entity )
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
