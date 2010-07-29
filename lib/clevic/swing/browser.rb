#~ require 'clevic/search_dialog.rb'
require 'clevic/view'
require 'clevic/swing/action_builder'

JTabbedPane = javax.swing.JTabbedPane
class JTabbedPane
  def each
    (0...tab_count).each do |index|
      yield component_at( index )
    end
  end
  include Enumerable
end

Component = java.awt.Component
class Component
  def <<( obj )
    case obj
    when Clevic::Separator
      add_separator
    
    when String
      add obj.to_java_string
    
    when Clevic::Action
      add obj.text.to_java_string
    
    else
      add obj
    end
  end
end

module Clevic

=begin rdoc
The main application class. Display one tabs for each descendant of Clevic::View
in Clevic::View.order. DefaultView classes created by Clevic::Record are automatically
added.
=end
class Browser < javax.swing.JFrame
  #~ slots *%w{dump() refresh_table() filter_by_current(bool) next_tab() previous_tab()}
  
  attr_reader :tables_tab
  attr_reader :menu_edit, :menu_search
  
  def initialize
    super
    
    # do menus and widgets
    # menu
    self.jmenu_bar = javax.swing.JMenuBar.new.tap do |menu_bar|
      menu_bar << javax.swing.JMenu.new( 'File' ).tap do |menu|
        menu.mnemonic = java.awt.event.KeyEvent::VK_F
        menu << "Open"
        menu << "Close"
      end
      
      @menu_edit = javax.swing.JMenu.new( 'Edit' ).tap {|m| m.mnemonic = java.awt.event.KeyEvent::VK_E}
      menu_bar << menu_edit
      
      @menu_search = javax.swing.JMenu.new( 'Search' ).tap {|m| m.mnemonic = java.awt.event.KeyEvent::VK_S}
      menu_bar << menu_search
      
      menu_bar << javax.swing.JMenu.new( 'Table' ).tap do |menu|
        menu.mnemonic = java.awt.event.KeyEvent::VK_T
        menu << Action.new( self ) do |action|
          action.name = :next_tab
          action.text = "&Next"
          action.shortcut = "Ctrl+Tab"
          action.handler do |event|
            puts "next tab"
            next_tab
          end
        end.menu_item
        
        menu << Action.new( self ) do |action|
          action.name = :previous_tab
          action.text = "&Previous"
          action.shortcut = "Shift+Ctrl+Tab"
          action.handler do |event|
            puts "previous tab"
            previous_tab
          end
        end.menu_item
        
        if $options[:debug]
          menu << Action.new( self ).tap do |action|
            action.name = :dump
            action.text = "&Dump"
            action.shortcut = "Ctrl+D"
            action.handler do |event|
              dump
            end
          end
        end
      end
    end
    
    # set icon. MUST come after call to setup_ui
    icon_path = Pathname.new( __FILE__ ).parent.parent + "icons/icon.png"
    raise "icon.png not found" unless icon_path.file?
    self.icon_image = javax.swing.ImageIcon.new( icon_path.realpath.to_s ).image
    
    # add the tables tab
    @tables_tab = javax.swing.JTabbedPane.new
    self.content_pane.add @tables_tab
    
    # tell tab to not take focus
    tables_tab.focusable = false
    
    # tab navigation
    @tables_tab.add_change_listener do |change_event|
      puts "change_event: #{change_event.source.inspect}"
      puts "change_event.source.selected_index: #{change_event.source.selected_index.inspect}"
      current_changed
      # TODO tell exiting tab to save currently editing row/cell
    end

    load_views
    update_menus
    self.title = [database_name, 'Clevic'].compact.join ' '
  end
  
  # Set the main window title to the name of the database, if we can find it.
  def database_name
    table_view.model.entity_class.db.url rescue ''
  end  
  
  def update_menus
    # update edit menu
    menu_edit.remove_all
    
    # do the model-specific menu items first
    table_view.model_actions.each do |action|
      menu_edit << action.menu_item
    end
    
    # now do the generic edit items
    table_view.edit_actions.each do |action|
      menu_edit << action.menu_item
    end
    
    # update search menu
    menu_search.remove_all
    table_view.search_actions.each do |action|
      menu_search << action.menu_item
    end
  end
  
  # activated by Ctrl-Shift-D for debugging
  def dump
    puts "table_view.model: #{table_view.model.inspect}"
    puts "table_view.model.entity_class: #{table_view.model.entity_class.inspect}"
  end
  
  # return the Clevic::TableView object in the currently displayed tab
  def table_view
    tables_tab.selected_component
  end
  
  # slot to handle Ctrl-Tab and move to next tab, or wrap around
  def next_tab
    tables_tab.selected_index = 
    if tables_tab.selected_index >= tables_tab.count - 1
      0
    else
      tables_tab.selected_index + 1
    end
  end

  # slot to handle Ctrl-Backtab and move to previous tab, or wrap around
  def previous_tab
    tables_tab.selected_index = 
    if tables_tab.selected_index <= 0
      tables_tab.count - 1
    else
      tables_tab.selected_index - 1
    end
  end
  
  # slot to handle the currentChanged signal from tables_tab, and
  # set focus on the grid
  def current_changed
    update_menus
    table_view.request_focus
  end
  
  # Create the tabs, each with a collection for a particular entity class.
  # views come from Clevic::View.order
  def load_views
    views = Clevic::View.order.uniq
    Kernel.raise "no views to display" if views.empty?
    
    # Add all existing model objects as tabs, one each
    views.each do |view_class|
      begin
        view = view_class.new
        unless view.entity_class.table_exists?
          puts "No table for #{view.entity_class.inspect}"
          next
        end
          
        # create the the table_view and the table_model for the entity_class
        tab = Clevic::TableView.new( view )
        
        # show status messages
        # TODO connect this
        #~ tab.connect( SIGNAL( 'status_text(QString)' ) ) { |msg| @layout.statusbar.show_message( msg, 10000 ) }
        
        # add a new tab
        tables_tab.add( tab.title, tab )
        
        puts "TODO: add the table to the Table menu"
        menu_table << Action.new( self ) do |action|
          action.text = tab.title
          action.handler do
            tables_tab.current_widget = tab
          end
        end
        
        # handle filter status changed, so we can provide a visual indication
        #~ tab.connect SIGNAL( 'filter_status(bool)' ) do |status|
          #~ # update the tab, so there's a visual indication of filtering
          #~ filter_title = ( tab.filtered ? '| ' : '' ) + translate( tab.title )
          #~ tables_tab.set_tab_text( tables_tab.current_index, filter_title )
        #~ end
      rescue Exception => e
        puts
        puts "UI from #{view} will not be available: #{e.message}"
        puts e.backtrace #if $options[:debug]
        puts
      end
    end
  end
  
  # make sure all outstanding records are saved
  def save_all
    tables_tab.each {|x| x.save_row( x.current_index ) }
  end
  
  def self.run( args )
    args.each do |arg|
      load_models( Pathname.new( arg ) )
    end
    browser = Browser.new
    browser.default_close_operation = javax.swing.JFrame::EXIT_ON_CLOSE
    browser.pack
    browser.visible = true 
  end
end

end
