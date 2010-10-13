require 'clevic/swing/delegate'

module Clevic

# Handle updates and notifications for the tag editor
class TagEditorModel
  include javax.swing.ListModel
  
  # Bit of a hack, but ok.
  attr_accessor :field
  attr_accessor :entity
  
  def initialize( field, entity )
    @field = field
    @entity = entity
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
  
  def linked_items
    @linked_items ||= FieldValuer.valuer( field, entity ).attribute_value
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
 
  # Returns the value at the specified index.
  # Object getElementAt(int index)
  def getElementAt(index)
    items[index]
  end
  
  # Returns the length of the list.
  # int getSize()
  def getSize()
    items.size
  end
  
  def as_text
    linked_items.map{|x| FieldValuer.valuer( field.many_fields.first, x ).display_value }.join(',')
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
  attr_reader :entity
  
  # Hopefully called by the editor framework
  def configureEditor( editor, entity )
    @entity = entity
    @linked_items = nil
    item_list.model = TagEditorModel.new( field, @entity )
    text_field.text = item_list.model.as_text
  end

  class CellRenderer < javax.swing.JComponent
    include Clevic::SimpleFieldValuer
    
    def initialize( tag_editor, item, width )
      super()
      @tag_editor, @item = tag_editor, item
      self.layout = javax.swing.BoxLayout.new( self, javax.swing.BoxLayout::X_AXIS )
      self << @checkbox = javax.swing.JCheckBox.new.tap do |checkbox|
        checkbox.text = display_value
      end
      self.preferred_size = java.awt.Dimension.new( width, @checkbox.preferred_size.height )
      validate
    end
    
    attr_reader :item
    
    def item=( value )
      @item = value
      @checkbox.text = display_value
    end
    
    def background=( color )
      self.setBackground( color )
      @checkbox.background = color
    end
    
    def focus=( bool )
      @checkbox.focus_painted = bool
    end
    
    def entity
      @item
    end
    
    def field
      @tag_editor.field.many_fields.first
    end
    
    def linked=( bool )
      @checkbox.selected = bool
    end
  end
  
  unless ancestors.include?( Java::JavaxSwing::ListCellRenderer )
    include javax.swing.ListCellRenderer
  end
  
  def getListCellRendererComponent( jlist, value, index, is_selected, cell_has_focus )
    @renderer ||= CellRenderer.new( self, value, jlist.width )
    @renderer.item = value
    
    # set colors
    @renderer.background = is_selected ? jlist.selection_background : jlist.background
    @renderer.foreground = is_selected ? jlist.selection_foreground : jlist.foreground
    
    # set existence
    @renderer.linked = linked_items.include?( value )
    
    # try to draw focus. Doesn't do much in a list view
    @renderer.focus = cell_has_focus
    
    @renderer.validate
    @renderer
  end
  
  def more_setup
    item_list.cell_renderer = self
  end
  
  def processKeyBinding( key_stroke, key_event, condition, pressed )
    if key_stroke.key_code == java.awt.event.KeyEvent::VK_SPACE
      puts "space"
    else
      super
    end
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
