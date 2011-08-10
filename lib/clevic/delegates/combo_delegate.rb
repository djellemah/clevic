require 'andand'

module Clevic

=begin rdoc
Base class for other delegates using Combo boxes.
=end
# TODO this should be a module
class ComboDelegate
  # Return the GUI component / widget that is displayed when editing.
  # Usually this will be a combo box widget, but it can be a text editor
  # in some cases.
  # if editor is a combo it must support no_insert=( bool )
  attr_reader :editor

  # Return a string to be shown to the user.
  # model_value is an item stored in the combo box model.
  def display_for( model_value )
    field.transform_attribute( model_value )
  end

  # Some GUIs (Qt) can just set this. Swing can't.
  def configure_prefix
  end

  # TODO kinda redundant because all combos must be editable
  # to support prefix matching
  def configure_editable
    editor.editable = true
  end

  # this will create the actual combo box widget
  framework_responsibility :create_combo_box

  # framework-specific code goes in here
  # it's called right at the end of init_component, once all the other setup
  # is done. Mainly it's so that event handlers can be attached
  # to the combo box without having to deal with events triggered
  # by setup code.
  framework_responsibility :framework_setup

  # This is called by the combo box to convert an item
  # to something that the combo can insert into
  # itself. Usually this will be a display value
  # and a storage value.
  framework_responsibility :item_to_editor

  # This is called by the combo box when it needs to convert a
  # storage value to an item, which is something that the delegate
  # will understand.
  framework_responsibility :editor_to_item

  # Create a GUI widget and fill it with the possible values.
  # *args will be passed as-is to framework_setup
  # NOTE RIght now it's the framework's responsibility to call
  #  self.entity = some_entity
  # There must be a good way to check that though.
  def init_component( *args )
    if needs_combo?
      @editor = create_combo_box( *args )
      @editor.delegate = self

      # add all entries from population
      population.each do |item|
        editor << item
      end

      # create a nil entry if necessary
      if allow_null? && !editor.include?( nil )
        editor << nil
      end

      # don't allow inserts if the delegate is restricted
      editor.no_insert = restricted?

      # set the correct value in the list
      editor.selected_item = entity.nil? ? nil : attribute_value      

      # set up prefix matching when typing in the editor
      configure_prefix

      framework_setup( *args )
    else
      @editor =
      if restricted?
        show_message( empty_set_message )
        nil
      else
        # there is no data yet for the combo, and it's
        # not restricted, so just edit with a simple text field.
        line_editor( edit_value )
      end
    end
    editor
  end

  # open the combo box, just like if F4 was pressed
  framework_responsibility :full_edit

  # show only the text editor part, not the drop-down
  def minimal_edit
    editor.hide_popup if is_combo?
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

  # Subclasses should override this to prove a list of
  # values to be used by the combo box. Values could
  # be pretty much anything, depending on the delegate.
  # For example, a RelationalDelegate will have a collection
  # of entity objects, most other delegates will have collections
  # of strings.
  subclass_responsibility :population

  # Return true if this delegate needs a combo, false otherwise
  # ie if there are no values yet and it's not restricted, then a
  # full combo doesn't make sense
  subclass_responsibility :needs_combo?

  # return true if this delegate has/needs a combo widget
  # or false if it's a plain text field.
  framework_responsibility :is_combo?

  # return true if this field has no data (needs_combo? is false)
  # and is at the same time restricted (ie needs data from somewhere else)
  def empty_set?
    !needs_combo? && restricted?
  end

  # the message to display if the set is empty, and
  # the delegate is restricted to a predefined set.
  subclass_responsibility :empty_set_message

  # if this delegate has an empty set, return the message, otherwise
  # return nil.
  def if_empty_message
    empty_set_message if empty_set?
  end

  # the value represented by the combo, ie either
  # the current attribute_value of the field
  # this combo is editing, or an object that could
  # be a new attribute_value
  framework_responsibility :value
end

end
