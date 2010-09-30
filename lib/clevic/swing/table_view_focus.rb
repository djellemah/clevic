module Clevic

  class TableViewFocus < java.awt.FocusTraversalPolicy
    def initialize( table_view )
      super()
      @table_view = table_view
      @table_view.focus_cycle_root = true
    end
    
    # Returns the Component that should receive the focus after aComponent.
    # def getComponentAfter(Container aContainer, Component aComponent)
    def getComponentAfter(container, component)
      @table_view.jtable
    end

    # Returns the Component that should receive the focus before aComponent.
    # def getComponentBefore(Container aContainer, Component aComponent)
    def getComponentBefore(container, component)
      @table_view.jtable
    end

    # Returns the default Component to focus.
    # def getDefaultComponent(Container aContainer)
    def getDefaultComponent(container)
      @table_view.jtable
    end

    # Returns the first Component in the traversal cycle.
    # def getFirstComponent(Container aContainer)
    def getFirstComponent(container)
      @table_view.jtable
    end
    
    # Returns the Component that should receive the focus when a Window is made visible for the first time.
    # Component 	getInitialComponent(Window window)
    def getInitialComponent(window)
      @table_view.jtable
    end
    
    # Returns the last Component in the traversal cycle.
    # def getLastComponent(Container aContainer)
    def getLastComponent(container)
      @table_view.jtable
    end
  end
  
end
