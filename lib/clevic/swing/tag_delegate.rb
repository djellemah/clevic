require 'clevic/swing/delegate'

module Clevic

# all this just to format a display item...
# .... and work around various other Swing stupidities
class TagEditor < javax.swing.JComponent
  def initialize( field )
    super()
    @field = field
    
    init_layout()
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

  def init_layout
    @text_field = javax.swing.JTextField.new
    @item_scroll = javax.swing.JScrollPane.new
    @item_list = javax.swing.JList.new
    @ok_button = javax.swing.JButton.new
    @cancel_button = javax.swing.JButton.new
    @add_button = javax.swing.JButton.new
    @remove_button = javax.swing.JButton.new

    @text_field.setName("text_field"); // NOI18N

    @item_scroll.setName("item_scroll"); // NOI18N

    @item_list.setName("item_list"); // NOI18N
    @item_scroll.setViewportView(item_list);

    @ok_button.setText("OK"); // NOI18N
    @ok_button.setToolTipText("Accept selection"); // NOI18N
    @ok_button.setName("ok_button"); // NOI18N

    @cancel_button.setText("Cancel"); // NOI18N
    @cancel_button.setName("cancel_button"); // NOI18N

    @add_button.setText("+"); // NOI18N
    @add_button.setToolTipText("Add a new item"); // NOI18N
    @add_button.setBorder(null);
    @add_button.setName("add_button"); // NOI18N

    @remove_button.setText("-"); // NOI18N
    @remove_button.setToolTipText("Remove selected item"); // NOI18N
    @remove_button.setBorder(null);
    @remove_button.setName("remove_button"); // NOI18N

    layout = org.jdesktop.layout.GroupLayout( self );
    setLayout(layout);
    layout.setHorizontalGroup(
        layout.createParallelGroup(org.jdesktop.layout.GroupLayout::LEADING)
        .add(layout.createSequentialGroup()
            .addContainerGap()
            .add(layout.createParallelGroup(org.jdesktop.layout.GroupLayout::LEADING)
                .add(item_scroll, org.jdesktop.layout.GroupLayout::DEFAULT_SIZE, 210, java.lang.Short::MAX_VALUE)
                .add(text_field, org.jdesktop.layout.GroupLayout::DEFAULT_SIZE, 210, java.lang.Short::MAX_VALUE)
                .add(layout.createSequentialGroup()
                    .add(ok_button)
                    .addPreferredGap(org.jdesktop.layout.LayoutStyle::RELATED, 82, java.lang.Short::MAX_VALUE)
                    .add(cancel_button))
                .add(layout.createSequentialGroup()
                    .add(add_button, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE, 27, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE)
                    .addPreferredGap(org.jdesktop.layout.LayoutStyle::RELATED)
                    .add(remove_button, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE, 27, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE)))
            .addContainerGap())
    );
    layout.setVerticalGroup(
        layout.createParallelGroup(org.jdesktop.layout.GroupLayout::LEADING)
        .add(layout.createSequentialGroup()
            .addContainerGap()
            .add(text_field, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE, org.jdesktop.layout.GroupLayout::DEFAULT_SIZE, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE)
            .add(18, 18, 18)
            .add(item_scroll, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE, 202, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE)
            .addPreferredGap(org.jdesktop.layout.LayoutStyle::RELATED)
            .add(layout.createParallelGroup(org.jdesktop.layout.GroupLayout::BASELINE)
                .add(add_button, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE, 20, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE)
                .add(remove_button, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE, 19, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE))
            .addPreferredGap(org.jdesktop.layout.LayoutStyle::RELATED, 30, java.lang.Short::MAX_VALUE)
            .add(layout.createParallelGroup(org.jdesktop.layout.GroupLayout::BASELINE)
                .add(ok_button)
                .add(cancel_button))
            .addContainerGap())
    );
  end
end

=begin rdoc
Delegate for doing simple multi-value fields. Tags, basically.
=end
class TagDelegate < Delegate
  # Create a GUI widget and fill it with the possible values.
  def init_component( cell_editor = nil )
    line_editor edit_value
    # This should be a collection of entities from the related table
    @items = attribute_value
  end
  
  # Return the GUI component / widget that is displayed when editing.
  # Usually this will be a combo box widget, but it can be a text editor
  # in some cases.
  attr_reader :editor
  
  # the cell must be selected before the edit can be clicked
  def needs_pre_selection?
    true
  end
  
  # Return a string to be shown to the user.
  # model_value is an item stored in the combo box model.
  def display_for( model_value )
    field.transform_attribute( model_value )
  end
  
  def line_editor( value = nil )
    @line_editor ||= javax.swing.JTextField.new( value ).tap do |line|
      line.font = Clevic.tahoma
    end
  end
  
  def editor
    line_editor
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
    # Must request focus and then once focus is received, show popup.
    # Otherwise focus received hides popup.
    invoke_later do
      #~ editor.add_focus_listener( LittleFocusPopper.new )
      #~ editor.request_focus_in_window
      editor.show_popup
    end
  end
  
  # open the text editor component
  #~ def minimal_edit
  #~ end
  
  # return an array of related entity objects, to be
  # passed into the attribute setter
  def value
    "the value"
  end
end

end
