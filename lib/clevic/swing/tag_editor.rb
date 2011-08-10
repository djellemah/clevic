require 'clevic/swing/delegate'

module Clevic

# all this just to format a display item...
# .... and work around various other Swing stupidities
class TagEditor < javax.swing.JComponent
  def initialize( field )
    super()
    @field = field

    create_fields
    init_layout
  end

  attr_reader :field
  attr_reader :entity

  # Hopefully called by the editor framework
  # might be init_component
  def configureEditor( editor, entity )
    @entity = entity
    item_list.model.one = entity
  end

  attr_reader :text_field, :item_list, :ok_button, :cancel_button, :add_button, :remove_button

  def create_fields
    @item_list = TableView.new( field.many_view )

    @text_field = javax.swing.JTextField.new
    @ok_button = javax.swing.JButton.new
    @cancel_button = javax.swing.JButton.new
    @add_button = javax.swing.JButton.new
    @remove_button = javax.swing.JButton.new
  end

  def init_layout
    # This is mostly cut-n-pasted from the Netbeans Java sources. So don't tweak it.
    text_field.setName("text_field");

    item_list.setName("item_list");

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
                .add(item_list, org.jdesktop.layout.GroupLayout::DEFAULT_SIZE, 210, java.lang.Short::MAX_VALUE) \
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
            .add(item_list, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE, 202, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE) \
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
