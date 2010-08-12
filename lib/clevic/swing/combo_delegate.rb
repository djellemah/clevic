require 'clevic/swing/delegate'

module Clevic

# all this just to format a display item...
class ComboBox < javax.swing.JComboBox
  def initialize( field )
    super()
    @field = field
  end
  
  def configureEditor( combo_box_editor, item )
    value =
    if @field.related_class && item.is_a?( @field.related_class )
      @field.transform_attribute( item )
    else
      item
    end
    
    combo_box_editor.item = value
    combo_box_editor.select_all
  end
end

=begin rdoc
Base class for other delegates using Combo boxes.
=end
class ComboDelegate < Delegate
  def initialize( field )
    super
    @autocompleting = false
  end
  
  # Return the GUI component / widget that is displayed when editing.
  # Usually this will be a combo box widget, but it can be a text editor
  # in some cases.
  attr_reader :editor
  
  def combo_class
    ComboBox
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
  
  # Return a string to be shown to the user.
  # model_value is an item stored in the combo box model.
  def display_for( model_value )
    field.transform_attribute( model_value )
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
  end
  
  # TODO kinda redundant because all combos must be editable
  # to support prefix matching
  def configure_editable
    editor.editable = true
  end
  
  # Create a GUI widget and fill it with the possible values.
  def init_component
    if needs_combo?
      @editor = create_combo_box
      
      # subclasses fill in the rest of the entries
      populate
      
      # add the current item, if it isn't there already
      # should therefore come after populate
      populate_current
      
      # create a nil entry
      add_nil_item if allow_null?
      
      # allow prefix matching from the keyboard
      configure_prefix
      
      # don't allow text editing if restricted
      configure_editable
      
      # set the correct value in the list
      select_current
      
      # pick up events from editor
      # but only after all the other config, otherwise we get
      # events triggered by the setup, which isn't helpful.
      editor.editor.editor_component.document.add_document_listener do |event|
        # don't do anything if autocomplete manipulations are in progress
        unless @autocompleting
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
    else
      @editor =
      if restricted?
        show_message( empty_set_message )
        nil
      else
        line_editor( edit_value )
      end
    end
    editor
  end
  
  # populate the combo box. Try overriding population first, otherwise
  # it might become necessary to also override filter_prefix
  def populate
    population.each do |item|
      editor << item
    end
  end
  
  # Recreate the model and fill it with anything in population that
  # matches the prefix, or all items if prefix is null.
  # Then set the editor text value to either text, or to the previous
  # value.
  # Order is important: if the text is set first it's overridden when
  # the model is populated.
  def repopulate( prefix = nil, text = nil )
    autocomplete do
      save_item = editor.editor.item
      prefix ||= editor.editor.item
      editor.model = editor.model.class.new
      matching, non_matching = population.partition{ |item| display_for( item ) =~ /^#{prefix}/i }
      matching.each {|item| editor << item}
      non_matching.each {|item| editor << item}
      editor.editor.item = text || save_item
      puts "#{__FILE__}:#{__LINE__}:TODO: set selected item"
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
    # search for matching item
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
  
  # open the combo box, just like if f4 was pressed
  def full_edit
    editor.show_popup if is_combo?
  end
  
  # open the combo box, just like if f4 was pressed
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
  
  # Subclasses should override this to fill the combo box
  # list with values.
  def population
    raise "subclass responsibility"
  end
  
  # return true if this delegate needs a combo, false otherwise
  def needs_combo?
    raise "subclass responsibility"
  end

  def is_combo?
    # Assume we're a combo if we don't have an editor yet, otherwise
    # check
    editor.nil? || editor.is_a?( javax.swing.JComboBox )
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
  # TODO this isn't included in population
  def populate_current
    # always add the current selection, if it isn't already there
    # and it makes sense. This is to make sure that if the list
    # is filtered, we always have the current value if the filter
    # excludes it
    item = attribute_value
    editor.insert_item_at( item, 0 ) if item && !editor.include?( item )
  end

  def add_nil_item
    editor << nil unless editor.include?( nil )
  end
  
  def select_current
    editor.selected_item = attribute_value
  end
  
  def value
    # editor could be either a combo or a line (DistinctDelegate with no values yet)
    if is_combo?
      if restricted?
        editor.selected_item 
      else
        puts "#{__FILE__}:#{__LINE__}:get the editor's text field value"
        editor.editor.item
      end
    else
      editor.text
    end
  end
end

end
