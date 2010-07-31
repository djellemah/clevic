AbstractButton = javax.swing.AbstractButton
class AbstractButton
  def mnemonic=( string_value )
    self.setMnemonic( string_value[0] )
  end
end

module Clevic
  class SearchDialog < javax.swing.JDialog
    def initialize( parent, modal = true )
      super(parent)
      self.modal = modal
      init_controls
      init_layout
    end

    attr_reader :match_flags
    
    def from_start?
      from_start.value
    end
    
    def from_start=( value )
      from_start.value = value
    end
    
    def regex?
      regex.value
    end
    
    def whole_words?
      whole_words.value
    end
    
    def forwards?
      forwards.checked?
    end
    
    def backwards?
      backwards.checked?
    end
    
    # return either :backwards or :forwards
    def direction
      return :forwards if forwards?
      return :backwards if backwards?
      raise "direction not known"
    end
    
    def exec( text = '' )
      search_combo.edit_text = text.to_s
      search_combo.set_focus
      retval = @dialog.exec
      
      # remember previous searches
      if search_combo.find_text( search_combo.current_text ) == -1
        search_combo.add_item( search_combo.current_text )
      end
      
      retval
    end
    
    def search_text
      search_combo.current_text
    end
    
    attr_reader :search_label, :search_combo
    attr_reader :from_start, :whole_words, :regex, :forwards, :backwards
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
      end

      @cancel_button = javax.swing.JButton.new.tap do |cancel_button|
        cancel_button.mnemonic = 'C'
        cancel_button.text = "Cancel"
        cancel_button.name = "cancel_button"
      end

      self.default_close_operation = javax.swing.WindowConstants::DISPOSE_ON_CLOSE
      self.name = "SearchDialog"
    end
    
    # this was originally Java, so it's really ugly.
    def init_layout
      content_pane.layout = javax.swing.GroupLayout.new( content_pane ).tap do |layout|
        
        # horizontal group
        layout.setHorizontalGroup(
          layout.createParallelGroup(javax.swing.GroupLayout::Alignment::LEADING) \
          .addGroup(layout.createSequentialGroup() \
            .addContainerGap() \
            .addGroup(layout.createParallelGroup(javax.swing.GroupLayout::Alignment::LEADING) \
              .addGroup(layout.createSequentialGroup() \
                .addGap(21, 21, 21) \
                .addComponent(search_label) \
                .addPreferredGap(javax.swing.LayoutStyle::ComponentPlacement::RELATED) \
                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout::Alignment::LEADING, false) \
                  .addComponent(search_combo, 0, 192, java.lang.Short::MAX_VALUE) \
                  .addComponent(from_start, javax.swing.GroupLayout::DEFAULT_SIZE, javax.swing.GroupLayout::DEFAULT_SIZE, java.lang.Short::MAX_VALUE) \
                  .addComponent(regex, javax.swing.GroupLayout::DEFAULT_SIZE, javax.swing.GroupLayout::DEFAULT_SIZE, java.lang.Short::MAX_VALUE) \
                  .addComponent(whole_words, javax.swing.GroupLayout::DEFAULT_SIZE, javax.swing.GroupLayout::DEFAULT_SIZE, java.lang.Short::MAX_VALUE) \
                  .addComponent(forwards, javax.swing.GroupLayout::DEFAULT_SIZE, javax.swing.GroupLayout::DEFAULT_SIZE, java.lang.Short::MAX_VALUE) \
                  .addComponent(backwards))) \
              .addGroup(layout.createSequentialGroup() \
                .addComponent(ok_button) \
                .addPreferredGap(javax.swing.LayoutStyle::ComponentPlacement::RELATED, 137, java.lang.Short::MAX_VALUE) \
                .addComponent(cancel_button))) \
            .addGap(20, 20, 20)
          )
        )
        
        # vertical group
        layout.setVerticalGroup(
          layout.createParallelGroup(javax.swing.GroupLayout::Alignment::LEADING) \
          .addGroup(layout.createSequentialGroup() \
            .addGap(31, 31, 31) \
            .addGroup(layout.createParallelGroup(javax.swing.GroupLayout::Alignment::BASELINE) \
              .addComponent(search_combo, javax.swing.GroupLayout::PREFERRED_SIZE, javax.swing.GroupLayout::DEFAULT_SIZE, javax.swing.GroupLayout::PREFERRED_SIZE) \
              .addComponent(search_label)
            ) \
            .addGap(18, 18, 18) \
            .addComponent(from_start) \
            .addPreferredGap(javax.swing.LayoutStyle::ComponentPlacement::RELATED) \
            .addComponent(regex) \
            .addPreferredGap(javax.swing.LayoutStyle::ComponentPlacement::RELATED) \
            .addComponent(whole_words) \
            .addGap(18, 18, 18) \
            .addComponent(forwards) \
            .addPreferredGap(javax.swing.LayoutStyle::ComponentPlacement::RELATED) \
            .addComponent(backwards) \
            .addGap(18, 18, 18) \
            .addGroup(layout.createParallelGroup(javax.swing.GroupLayout::Alignment::BASELINE) \
              .addComponent(ok_button) \
              .addComponent(cancel_button)
            ) \
            .addContainerGap(27, java.lang.Short::MAX_VALUE)
          )
        )
      end
      pack
    end
  end

end
