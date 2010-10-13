require 'clevic/swing/delegate'

module Clevic

# Handle updates and notifications for the tag editor
class TagEditorModel
  include javax.swing.ListModel
  #~ include javax.swing.DocumentModel
  
  # Bit of a hack, but ok.
  attr_accessor :field
  
  def initialize( field )
    @field = field
    @listeners = []
  end
  
  # Adds a listener to the list that's notified each time a change to the data model occurs.
  def addListDataListener(list_data_listener)
    @listeners << list_data_listener
  end
  
  def removeListDataListener(list_data_listener)
    @listeners.delete list_data_listener
  end
  
  def items
    field.related_class.all
  end
  
  def items=( ary )
    @items = ary
    @listeners.each do |list_data_listener|
      event = javax.swing.event.ListDataEvent( self, javax.swing.event.ListDataEvent::CONTENTS_CHANGED, 0, ary.size - 1) 
      list_data_listener.contentsChanged( event )
    end
  end
  
      #~ *   CONTENTS_CHANGED
    #~ * INTERVAL_ADDED
    #~ * INTERVAL_REMOVED 
   #~ void 	contentsChanged(ListDataEvent e)
          #~ Sent when the contents of the list has changed in a way that's too complex to characterize with the previous methods.
 #~ void 	intervalAdded(ListDataEvent e)
          #~ Sent after the indices in the index0,index1 interval have been inserted in the data model.
 #~ void 	intervalRemoved(ListDataEvent e) 
 
  class Valuer
    include Clevic::SimpleFieldValuer
  end
  
  def valuer
    @valuer ||= Valuer.new.tap{|v| v.field = field.many_fields.first}
  end
 
  # Returns the value at the specified index.
  # Object getElementAt(int index)
  def getElementAt(index)
    valuer.entity = items[index]
    valuer.display_value
  end
  
  # Returns the length of the list.
  # int getSize()
  def getSize()
    items.size
  end
  
  def as_text
    items.map{|x| self.entity = x; display_value}.join(',')
  end
end

# all this just to format a display item...
# .... and work around various other Swing stupidities
class TagEditor < javax.swing.JComponent
  def initialize( field )
    super()
    @field = field
    
    create_fields
    init_layout
    more_setup
  end
  
  attr_reader :field
  
  def configureEditor( combo_box_editor, item )
    value =
    if @field.related_class && item.is_a?( @field.related_class )
      @field.transform_attribute( item )
    else
      item
    end
    
    editor.model = TagEditorModel.new( field )
  end
  
  class CellRenderer < javax.swing.JComponent
    def initialize( item )
      
    end
  end
  
  unless ancestors.include?( Java::JavaxSwing::ListCellRenderer )
    include javax.swing.ListCellRenderer
  end
  
  def getListCellRendererComponent( jlist, value, index, is_selected, cell_has_focus )
    @renderer ||= javax.swing.JLabel.new
    @renderer.text = value.andand.to_s || 'enmpty value'
    @renderer
  end
  
  def more_setup
    item_list.cell_renderer = self
    item_list.model = TagEditorModel.new( field )
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
  
  attr_reader :text_field, :item_scroll, :item_list, :ok_button, :cancel_button, :add_button, :remove_button

  def create_fields
    @text_field = javax.swing.JTextField.new
    @item_scroll = javax.swing.JScrollPane.new
    @item_list = javax.swing.JList.new
    @ok_button = javax.swing.JButton.new
    @cancel_button = javax.swing.JButton.new
    @add_button = javax.swing.JButton.new
    @remove_button = javax.swing.JButton.new
  end
  
  def init_layout
    # This is mostly cut-n-pasted from the Netbeans Java sources. So don't tweak it.
    text_field.setName("text_field");

    item_scroll.setName("item_scroll");

    item_list.setName("item_list");
    item_scroll.setViewportView(item_list);

    ok_button.setText("OK");
    ok_button.setToolTipText("Accept edits");
    ok_button.setName("ok_button");

    cancel_button.setText("Cancel");
    cancel_button.setToolTipText("Cancel edits");
    cancel_button.setName("cancel_button");

    add_button.setText("+");
    add_button.setToolTipText("Add a new item");
    add_button.setBorder(nil);
    add_button.setName("add_button");

    remove_button.setText("-");
    remove_button.setToolTipText("Remove selected item");
    remove_button.setBorder(nil);
    remove_button.setName("remove_button");

    layout = org.jdesktop.layout.GroupLayout.new( self );
    setLayout(layout);
    layout.setHorizontalGroup(
        layout.createParallelGroup(org.jdesktop.layout.GroupLayout::LEADING) \
        .add(layout.createSequentialGroup() \
            .addContainerGap() \
            .add(layout.createParallelGroup(org.jdesktop.layout.GroupLayout::LEADING) \
                .add(item_scroll, org.jdesktop.layout.GroupLayout::DEFAULT_SIZE, 210, java.lang.Short::MAX_VALUE) \
                .add(text_field, org.jdesktop.layout.GroupLayout::DEFAULT_SIZE, 210, java.lang.Short::MAX_VALUE) \
                .add(layout.createSequentialGroup() \
                    .add(ok_button) \
                    .addPreferredGap(org.jdesktop.layout.LayoutStyle::RELATED, 82, java.lang.Short::MAX_VALUE) \
                    .add(cancel_button)) \
                .add(layout.createSequentialGroup() \
                    .add(add_button, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE, 27, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE) \
                    .addPreferredGap(org.jdesktop.layout.LayoutStyle::RELATED) \
                    .add(remove_button, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE, 27, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE))) \
            .addContainerGap()) \
    );
    layout.setVerticalGroup(
        layout.createParallelGroup(org.jdesktop.layout.GroupLayout::LEADING) \
        .add(layout.createSequentialGroup() \
            .addContainerGap() \
            .add(text_field, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE, org.jdesktop.layout.GroupLayout::DEFAULT_SIZE, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE) \
            .add(18, 18, 18) \
            .add(item_scroll, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE, 202, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE) \
            .addPreferredGap(org.jdesktop.layout.LayoutStyle::RELATED) \
            .add(layout.createParallelGroup(org.jdesktop.layout.GroupLayout::BASELINE) \
                .add(add_button, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE, 20, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE) \
                .add(remove_button, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE, 19, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE)) \
            .addPreferredGap(org.jdesktop.layout.LayoutStyle::RELATED, 30, java.lang.Short::MAX_VALUE) \
            .add(layout.createParallelGroup(org.jdesktop.layout.GroupLayout::BASELINE) \
                .add(ok_button) \
                .add(cancel_button)) \
            .addContainerGap()) \
    );
  end
end

end
