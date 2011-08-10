module Clevic
  # keeps a list of names => results mappings
  # and returns
  class ConfirmDialog
    def initialize
      @names = []
      @results = []
      yield self if block_given?
    end

    attr_accessor :names, :results, :question, :title, :dialog_result, :parent

    def to_java( arg )
      @options.keys.to_java( arg )
    end

    def canonical_results
      @canonical_results ||= [:accept, :reject]
    end

    # To create a an Ok button that has the focus, and causes
    # the class to return true from accepted?
    #  dialog['Ok'] = :accept, true
    #
    # To create a Cancel button that returns true from rejected?
    #  dialog['Cancel'] = :reject
    def []=( name, *args )
      result, default = *args.flatten
      raise "Result is not in #{@canonical_results.inspect}" unless canonical_results.include?( result.to_sym )
      names << name.to_s
      results << result.to_sym
      @default = name.to_s if default
    end

    def accepted?
      results[dialog_result] == :accept
    end

    def rejected?
      results[dialog_result] == :reject
    end

    def show
      self.dialog_result = javax.swing.JOptionPane.showOptionDialog(
        parent,
        question,
        title,
        javax.swing.JOptionPane::DEFAULT_OPTION,
        javax.swing.JOptionPane::QUESTION_MESSAGE,
        nil, # icon. Not used here
        names.to_java( :object ),
        @default
      )
      self
    end
  end
end
