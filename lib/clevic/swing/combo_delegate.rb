require 'andand'
require 'clevic/swing/delegate'

module Clevic

# all this just to format a display item...
# .... and work around various other Swing stupidities
class ComboBox < javax.swing.JComboBox
  def initialize( field )
    super()
    @field = field
  end
  
  # set to true by processKeyBinding when a character
  # key is pressed. Used by the autocomplete code.
  attr_reader :typing
  
  def configureEditor( combo_box_editor, item )
    value =
    if @field.related_class && item.is_a?( @field.related_class )
      @field.transform_attribute( item )
    else
      item
    end
    
    combo_box_editor.item = value
  end

  # Get the first keystroke when editing starts, and make sure it's entered
  # into the combo box text edit component, if it's not an action key.
  def processKeyBinding( key_stroke, key_event, condition, pressed )
    if key_event.typed? && !key_event.action_key?
      editor.editor_component.text = java.lang.Character.new( key_event.key_char ).toString
    end
    @typing = !key_event.action_key?
    super
  end
end

=begin rdoc
Base class for other delegates using Combo boxes.
=end
# FIXME error with keyboard handling
# To duplicate:
# - press F2
# - use arrows to select
# - Press Enter
# - press Tab or Shift-Tab
class ComboDelegate < Delegate
  def initialize( field )
    super
    @autocompleting = false
  end
  
  def combo_class
    ComboBox
  end
  
  # the cell must be selected before the edit can be clicked
  def needs_pre_selection?
    true
  end
  
  def create_combo_box
    # create a new combo class each time, otherwise
    # we have to get into managing cleaning out the model
    # and so on
    combo_class.new( field ).tap do |combo|
      combo.font = Clevic.tahoma
      
      # allow for transform of objects to their requested display values
      @original_renderer = combo.renderer
      combo.renderer = self
    end
  end
  
  include javax.swing.ListCellRenderer
  
  # return the component to render the values in the list
  # we just transform the value, and pass it to the
  # pre-existing renderer for the combo.
  def getListCellRendererComponent(jlist, value, index, selected, cell_has_focus)
    @original_renderer.getListCellRendererComponent(jlist, display_for( value ), index, selected, cell_has_focus)
  end
  
  # return a new text editor. This is for distinct_delegate when there
  # are no other values to choose from.
  # TODO move into distinct_delegate then?
  def line_editor( value )
    @line_editor ||= javax.swing.JTextField.new( value ).tap do |line|
      line.font = Clevic.tahoma
    end
  end
  
  # Some GUIs (Qt) can just set this. Swing can't.
  def configure_prefix
    # pick up events from editor
    # but only after all the other config, otherwise we get
    # events triggered by the setup, which isn't helpful.
    editor.editor.editor_component.document.add_document_listener do |event|
      # don't do anything if autocomplete manipulations are in progress
      unless @autocompleting || !editor.typing
        if event.type == javax.swing.event.DocumentEvent::EventType::REMOVE
          invoke_later do
            repopulate
          end
        else
          # only suggest on inserts and updates. Not on deletes.
          filter_prefix( editor.editor.item )
        end
      end
    end
  end
  
  def framework_setup
    # catch the enter key action event
    editor.editor.editor_component.add_action_listener do |event|
      cell_editor.andand.stopCellEditing
    end
    
    # set initial focus and selection in edit part of combo
    editor.editor.editor_component.with do |text_edit|
      unless text_edit.text.nil?
        # highlight the suggested match, and leave caret
        # at the end of the selected text
        text_edit.caret_position = 0
        text_edit.move_caret_position( text_edit.text.length )
        text_edit.request_focus_in_window
      end
    end
  end
  
  # Recreate the model and fill it with anything in population that
  # matches the prefix first, followed by anything in the population that
  # doesn't match the prefix.
  # Then set the editor text value to either text, or to the previous
  # value.
  # Order is important: if the text is set first it's overridden when
  # the model is populated.
  def repopulate( prefix = nil, text = nil )
    autocomplete do
      # save text and popup
      save_item = editor.editor.item
      dropdown_visible = editor.popup_visible?
      
      # repopulate based on the prefix
      prefix ||= editor.editor.item
      editor.model = editor.model.class.new
      # split set into things to display at the top, and things to display further down
      matching, non_matching = population.partition{ |item| display_for( item ) =~ /^#{prefix}/i }
      matching.each {|item| editor << item}
      non_matching.each {|item| editor << item}
      
      # restore text and popup
      editor.editor.item = text || save_item
      editor.popup_visible = dropdown_visible
    end
  end
    
  # make sure we don't react to document change events
  # while we're doing autocompletion. Reentrant
  def autocomplete( &block )
    @autocompleting = true
    yield
  ensure
    @autocompleting = false
  end
  
  # http://www.drdobbs.com/184404457 for autocompletion steps
  def filter_prefix( prefix )
    # search for matching item in the UI display_for for the items in the combo model
    candidate = population.map{|item| display_for( item ) }.select {|x| x =~ /^#{prefix}/i }.first
    unless candidate.nil?
      first_not_of = candidate.match( /^#{prefix}/i ).offset(0).last
      invoke_later do
        autocomplete do
          # set the shortlist, and the text editor value
          repopulate prefix, candidate
          
          # set the suggestion selection
          editor.editor.editor_component.with do |text_edit|
            # highlight the suggested match, and leave caret
            # at the beginning of the suggested text
            text_edit.caret_position = candidate.length
            text_edit.move_caret_position( first_not_of )
          end
        end
      end
    end
  end
  
  # open the combo box, just like if F4 was pressed
  # big trouble here with JComboBox firing an comboEdited action
  # (probably) on focusGained
  # which causes the popup to be hidden again
  def full_edit
    if is_combo?
      # Must request focus and then once focus is received, show popup.
      # Otherwise focus received hides popup.
      invoke_later do
        #~ editor.add_focus_listener( LittleFocusPopper.new )
        #~ editor.request_focus_in_window
        editor.show_popup
      end
    end
  end
  
  # open the combo box, just like if f4 was pressed
  def minimal_edit
    editor.hide_popup if is_combo?
  end
  
  def is_combo?
    # Assume we're a combo if we don't have an editor yet, otherwise
    # check
    editor.nil? || editor.is_a?( javax.swing.JComboBox )
  end
  
  def value
    # editor could be either a combo or a line (DistinctDelegate with no values yet)
    if is_combo?
      if restricted?
        editor.selected_item
      else
        puts "#{__FILE__}:#{__LINE__}:get the editor's text field value. Take away this output when we know it works. Ie when this gets printed."
        editor.editor.item
      end
    else
      puts "#{__FILE__}:#{__LINE__}:line item value: #{editor.text}"
      editor.text
    end
  end
end

end
