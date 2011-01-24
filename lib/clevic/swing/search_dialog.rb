require 'clevic/extensions.rb'
require 'clevic/swing/extensions.rb'

module Clevic
  class SearchDialog < javax.swing.JDialog
    def initialize( parent = nil, modal = true )
      if parent
        # JDK 5 barfs on this
        super(parent)
      else
        super()
      end
      
      init_controls
      init_layout
      
      self.default_close_operation = javax.swing.WindowConstants::HIDE_ON_CLOSE
      self.name = "SearchDialog"
      self.modal = modal
      self.title = "Search"
      
      # Enter triggers Ok button
      root_pane.default_button = ok_button
      
      # TODO finish this for Esc key to close dialog
      #~ esc = javax.swing.KeyStroke.getKeyStroke( KeyEvent.VK_ESCAPE, 0 )
      #~ root_pane.registerKeyboardAction( actionListener, stroke, javax.swing.JComponent.WHEN_IN_FOCUSED_WINDOW )
    end
    
    # after the dialog, this will be either accepted or rejected
    attr_reader :status
    
    def from_start?
      from_start.selected
    end
    
    def from_start=( value )
      from_start.selected = value
    end
    
    def regex?
      regex.selected
    end
    
    def whole_words?
      whole_words.selected
    end
    
    def forwards?
      forwards.selected
    end
    
    def backwards?
      backwards.selected
    end
    
    # return either :backwards or :forwards
    def direction
      return :forwards if forwards?
      return :backwards if backwards?
      raise "direction not known"
    end
    
    # show the dialog, wait for close,
    # return an object that understands rejected? and accepted?
    def exec( text = '' )
      self.search_text = text
      search_combo.request_focus
      search_combo.editor.select_all
      
      # modal dialog, so this will wait
      show
      
      # remember previous searches
      unless search_combo.include?( search_text )
        search_combo << search_text
      end
      
      self
    end
    
    def search_text=( value )
      search_combo.editor.item = value.to_s
    end
    
    def search_text
      search_combo.editor.item
    end
    
    def accepted?
      status == :accept
    end
    
    def accept!
      @status = :accept
    end
    
    def rejected?
      status == :reject
    end
    
    def reject!
      @status = :reject
    end
    
    attr_reader :search_label, :search_combo
    attr_reader :from_start, :whole_words, :regex
    attr_reader :forwards, :backwards
    attr_reader :ok_button, :cancel_button
    
    def init_controls
      @search_label = javax.swing.JLabel.new( "Search" ).tap do |search_label|
        search_label.text = "Search"
        search_label.name = "search_label"
      end
      
      @search_combo = javax.swing.JComboBox.new.tap do |search_combo|
        search_combo.editable = true
        search_combo.name = "search_combo"
      end
      
      @from_start = javax.swing.JCheckBox.new.tap do |from_start|
        from_start.mnemonic = 'S'
        from_start.text = "From Start"
        from_start.name = "from_start"
      end
      
      @regex = javax.swing.JCheckBox.new.tap do |regex|
        regex.mnemonic = 'R'
        regex.text = "Regular Expression"
        regex.name = "regex"
      end
      
      @whole_words = javax.swing.JCheckBox.new.tap do |whole_words|
        whole_words.mnemonic = 'W'
        whole_words.text = "Whole words"
        whole_words.name = "whole_words"
      end
      
      @forwards = javax.swing.JRadioButton.new.tap do |forwards|
        forwards.mnemonic = 'F'
        forwards.text = "Forwards"
        forwards.name = "forwards"
        forwards.selected = true
      end
      
      @backwards = javax.swing.JRadioButton.new.tap do |backwards|
        backwards.mnemonic = 'B'
        backwards.text = "Backwards"
        backwards.name = "backwards"
      end

      @ok_button = javax.swing.JButton.new.tap do |ok_button|
        ok_button.mnemonic = 'O'
        ok_button.text = "Ok"
        ok_button.name = "ok_button"
        ok_button.add_action_listener do |event|
          hide
          accept!
        end
      end

      @cancel_button = javax.swing.JButton.new.tap do |cancel_button|
        cancel_button.mnemonic = 'C'
        cancel_button.text = "Cancel"
        cancel_button.name = "cancel_button"
        cancel_button.add_action_listener do |event|
          hide
          reject!
        end
      end
    end
    
    # this was originally Java from NetBeans, so it's really ugly.
    # Note that for 1.5 compatibility, we have to use org.jdesktop.layout.GroupLayout
    # and include swing-layout-1.0.3.jar
    def init_layout
      content_pane.layout = org.jdesktop.layout.GroupLayout.new( content_pane ).tap do |layout|
        getContentPane().setLayout(layout);
        layout.setHorizontalGroup( \
            layout.createParallelGroup(org.jdesktop.layout.GroupLayout::LEADING) \
            .add(layout.createSequentialGroup() \
                .addContainerGap() \
                .add(layout.createParallelGroup(org.jdesktop.layout.GroupLayout::LEADING) \
                    .add(layout.createSequentialGroup() \
                        .add(21, 21, 21) \
                        .add(search_label) \
                        .addPreferredGap(org.jdesktop.layout.LayoutStyle::RELATED) \
                        .add(layout.createParallelGroup(org.jdesktop.layout.GroupLayout::LEADING, false) \
                            .add(search_combo, 0, 192, java.lang.Short::MAX_VALUE) \
                            .add(from_start, org.jdesktop.layout.GroupLayout::DEFAULT_SIZE, org.jdesktop.layout.GroupLayout::DEFAULT_SIZE, java.lang.Short::MAX_VALUE) \
                            .add(regex, org.jdesktop.layout.GroupLayout::DEFAULT_SIZE, org.jdesktop.layout.GroupLayout::DEFAULT_SIZE, java.lang.Short::MAX_VALUE) \
                            .add(whole_words, org.jdesktop.layout.GroupLayout::DEFAULT_SIZE, org.jdesktop.layout.GroupLayout::DEFAULT_SIZE, java.lang.Short::MAX_VALUE) \
                            .add(forwards, org.jdesktop.layout.GroupLayout::DEFAULT_SIZE, org.jdesktop.layout.GroupLayout::DEFAULT_SIZE, java.lang.Short::MAX_VALUE) \
                            .add(backwards))) \
                    .add(layout.createSequentialGroup() \
                        .add(ok_button) \
                        .addPreferredGap(org.jdesktop.layout.LayoutStyle::RELATED, 160, java.lang.Short::MAX_VALUE) \
                        .add(cancel_button))) \
                .add(16, 16, 16)) \
        );
        layout.setVerticalGroup(
            layout.createParallelGroup(org.jdesktop.layout.GroupLayout::LEADING) \
            .add(org.jdesktop.layout.GroupLayout::TRAILING, layout.createSequentialGroup() \
                .addContainerGap(23, java.lang.Short::MAX_VALUE) \
                .add(layout.createParallelGroup(org.jdesktop.layout.GroupLayout::BASELINE) \
                    .add(search_combo, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE, org.jdesktop.layout.GroupLayout::DEFAULT_SIZE, org.jdesktop.layout.GroupLayout::PREFERRED_SIZE) \
                    .add(search_label)) \
                .add(18, 18, 18) \
                .add(from_start) \
                .addPreferredGap(org.jdesktop.layout.LayoutStyle::RELATED) \
                .add(regex) \
                .addPreferredGap(org.jdesktop.layout.LayoutStyle::RELATED) \
                .add(whole_words) \
                .add(18, 18, 18) \
                .add(forwards) \
                .addPreferredGap(org.jdesktop.layout.LayoutStyle::RELATED) \
                .add(backwards) \
                .add(18, 18, 18) \
                .add(layout.createParallelGroup(org.jdesktop.layout.GroupLayout::BASELINE) \
                    .add(ok_button) \
                    .add(cancel_button)) \
                .add(20, 20, 20)) \
        );
      end
      pack
    end
  end

end
