#~ require 'clevic/search_dialog.rb'
require 'clevic/view'
require 'clevic/swing/action_builder'

module Clevic

=begin rdoc
The main application class. Display one tabs for each descendant of Clevic::View
in Clevic::View.order. DefaultView classes created by Clevic::Record are included.
=end
class Browser < javax.swing.JFrame
  attr_reader :menu_edit, :menu_search, :menu_table

  def initialize
    super

    # set OSX application title
    java.lang.System.setProperty( "com.apple.mrj.application.apple.menu.about.name", title_string )

    self.jmenu_bar = menu_bar
    self.icon_image = icon

    # add the tables tab
    add( tables_tab, java.awt.BorderLayout::CENTER )

    # add the status bar
    add( status_bar, java.awt.BorderLayout::SOUTH )

    load_views
    update_menus
    self.title = title_string
  end

  def title_string
    [database_name, 'Clevic'].compact.join ' '
  end

  def menu_bar
    javax.swing.JMenuBar.new.tap do |menu_bar|
      menu_bar << javax.swing.JMenu.new( 'File' ).tap do |menu|
        menu.mnemonic = java.awt.event.KeyEvent::VK_F
        menu << "Open"
        menu << "Close"
      end

      @menu_edit = javax.swing.JMenu.new( 'Edit' ).tap {|m| m.mnemonic = java.awt.event.KeyEvent::VK_E}
      menu_bar << menu_edit

      @menu_search = javax.swing.JMenu.new( 'Search' ).tap {|m| m.mnemonic = java.awt.event.KeyEvent::VK_S}
      menu_bar << menu_search

      @menu_table = javax.swing.JMenu.new( 'Table' ).tap do |menu|
        menu.mnemonic = java.awt.event.KeyEvent::VK_T
        menu << Action.new( self ) do |action|
          action.name = :next_tab
          action.text = "&Next"
          action.shortcut = "Ctrl+Tab"
          action.handler do |event|
            puts "next tab"
            next_tab
          end
        end

        menu << Action.new( self ) do |action|
          action.name = :previous_tab
          action.text = "&Previous"
          action.shortcut = "Shift+Ctrl+Tab"
          action.handler do |event|
            puts "previous tab"
            previous_tab
          end
        end

        if $options[:debug]
          menu << Action.new( self ) do |action|
            action.name = :dump
            action.text = "&Dump"
            action.shortcut = "Ctrl+D"
            action.handler do |event|
              dump
            end
          end
        end
      end
      menu_bar << @menu_table
    end
  end

  def icon
    @icon ||=
    begin
      icon_path = Pathname.new( __FILE__ ).parent.parent + "icons/icon.png"
      raise "icon.png not found" unless icon_path.file?
      javax.swing.ImageIcon.new( icon_path.realpath.to_s ).image
    end
  end

  def tables_tab
    @tables_tab ||= javax.swing.JTabbedPane.new.tap do |tables_tab|
      # tell tab to not take focus
      tables_tab.focusable = false

      # tab navigation
      tables_tab.add_change_listener do |change_event|
        current_changed
        # TODO tell exiting tab to save currently editing row/cell
      end
    end
  end

  def status_bar
    @status_bar ||= javax.swing.JLabel.new.tap do |status_bar|
      status_bar.horizontal_alignment = javax.swing.SwingConstants::RIGHT
      # just so the bar actually displays
      status_bar.text = "Welcome to Clevic"
    end
  end

  def status_bar_timer
    @status_bar_timer ||= javax.swing.Timer.new( 15000, nil ).tap do |timer|
      timer.repeats = false
      # This is only for 1.6
      #~ timer.action_command = 'hide_status_message'
      timer.add_action_listener do |event|
        status_bar.text = nil
        timer.stop
      end
    end
  end

  # Set the main window title to the name of the database, if we can find it.
  def database_name
    table_view.model.entity_class.db.url rescue ''
  end

  # called by current_changed to update the Edit menu to the menus
  # defined by the currently selected view
  def update_menus
    # update edit menu
    menu_edit.remove_all

    # do the model-specific menu items first
    table_view.model_actions.each do |action|
      menu_edit << action
    end

    # now do the generic edit items
    table_view.edit_actions.each do |action|
      menu_edit << action
    end

    # update search menu
    menu_search.remove_all
    table_view.search_actions.each do |action|
      menu_search << action
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
    views = Clevic::View.views
    Kernel.raise "no views to display" if views.empty?

    # Add all existing model objects as tabs, one each
    views.each do |view_class|
      begin
        view = view_class.new
        unless view.entity_class.table_exists?
          puts "Browser::load_views: No table for #{view.entity_class.inspect}"
          next
        end

        # create the the table_view and the table_model for the entity_class
        tab = Clevic::TableView.new( view )

        # add a new tab
        tables_tab.add( tab.title, tab )

        # add the table to the Table menu
        menu_table << Action.new( self ) do |action|
          action.text = tab.title
          action.handler do
            tables_tab.current = tab
          end
        end

        init_connections( tab )
      rescue Exception => e
        puts "UI from #{view} will not be available: #{e.message}"
        puts e.backtrace
      end
    end
  end

  def init_connections( tab )
    tab.emit_status_text do |msg|
      status_bar.text = msg
      # hide the message after a while.
      status_bar_timer.start
    end

    # handle filter status changed, so we can provide a visual indication
    tab.emit_filter_status do |status|
      # update the tab, so there's a visual indication of filtering
      filter_title = ( tab.filtered? ? '| ' : '' ) + tab.title
      tables_tab.set_title_at( tables_tab.selected_index, filter_title )
      tables_tab.set_tool_tip_text_at( tables_tab.selected_index, tab.filter_message )
    end
  end

  # make sure all outstanding records are saved
  def save_all
    tables_tab.each {|x| x.save_row( x.current_index ) }
  end

  def self.run( args )
    # make it more appley
    java.lang.System.setProperty( "apple.laf.useScreenMenuBar", "true" )
    javax.swing.UIManager.setLookAndFeel( javax.swing.UIManager.getSystemLookAndFeelClassName() )

    # load models
    args.each do |arg|
      load_models( Pathname.new( arg ) )
    end

    # make top-level UI
    browser = Browser.new
    browser.default_close_operation = javax.swing.JFrame::EXIT_ON_CLOSE
    browser.pack
    browser.visible = true 
  end
end

end
