# This has all the code for handling pasting
require 'hpricot'

module Clevic

class PasteError < RuntimeError
end

class TableView
  # get something from the clipboard and put it at the current selection
  # intended to be called by action / keyboard / menu handlers
  def paste
    busy_cursor do
      sanity_check_read_only

      # Try text/html then text/plain as tsv or csv
      # LATER maybe use the java-native-application at some point for
      # cut'n'paste internally?
      case
      when clipboard.html?
        paste_html
      when clipboard.text?
        paste_text
      else
        raise PasteError, "clipboard has neither text nor html, so can't paste"
      end
    end
  rescue PasteError => e
    show_error e.message
  end

  # Paste suitable html to the selection
  # Check for presence of tr tags, and make sure there are no colspan or rowspan attributes
  # on td tags.
  def paste_html
    emit_status_text "Fetching data."
    html = clipboard.html

    # This should really be factored out somewhere and tested thoroughly
    emit_status_text "Analysing data."
    doc =
    if html.is_a? Hpricot::Doc
      html
    else
      Hpricot.parse( html )
    end

    # call the plain text paste if we don't have tabular data
    if doc.search( "//tr" ).size == 0
      paste_text
    else
      # throw exception if there are [col|row]span > 1
      spans = doc.search( "//td[@rowspan > 1 || @colspan > 1]" )
      if spans.size > 0
        # make an itemised list of 
        cell_list = spans.map{|x| "- #{x.inner_text}"}.join("\n")
        raise PasteError, <<-EOF
  Pasting will not work because source contains spanning cells.
  If the source is a spreadsheet, you probably have merged cells
  somewhere. Split them, and try copy and paste again.
  Cells contain
  #{cell_list}
        EOF
      end

      # run through the tabular data and convert to simple array
      emit_status_text "Pasting data."
      ary = ( doc / :tr ).map do |row|
        ( row / :td ).map do |cell|
          # trim leading and trailing \r\n\t

          # check for br
          unless cell.search( '//br' ).empty?
            # treat br as separate lines
            cell.search('//text()').map( &:to_s ).join("\n")
          else
            # otherwise just join text elements
            cell.search( '//text()' ).join('')
          end.gsub( /^[\r\n\t]*/, '').gsub( /[\r\n\t]*$/, '')
        end
      end

      paste_array ary
    end
  end

  # LATER probably need a PasteParser or something, to figure
  # out if a file is tsv or csv
  # Try tsv first, because number formats often have embedded ','.
  # if tsv doesn't work, try with csv and test for rectangularness
  # otherwise assume it's one string.
  # TODO could also heuristically check paste selection area
  def paste_text
    text = clipboard.text

    case text
      when /\t/
        paste_array( CSV.parse( text, :col_sep => "\t" ) )
      # assume multi-line text, or text with commas, is csv
      when /[,\n]/
        paste_array( CSV.parse( text, :col_sep => ',' ) )
      else
        paste_value_to_selection( text )
    end
  end

  # Paste array to either a single selection or a matching multiple selection
  # TODO Check for rectangularness, ie csv_arr.map{|row| row.size}.uniq.size == 1
  def paste_array( arr )
    if selection_model.single_cell?
      # only one cell selected, so paste like a spreadsheet
      selected_index = selection_model.selected_indexes.first
      if arr.size == 0 or ( arr.size == 1 and arr.first.size == 0 )
        # empty array, so just clear the current selection
        selected_index.attribute_value = nil
      else
        paste_to_index( selected_index, arr )
      end
    else
      if arr.size == 1 && arr.first.size == 1
        # single value to multiple selection
        paste_value_to_selection arr.first.first
      else
        if selection_model.ranges.size != 1
          raise PasteError, "Can't paste tabular data to multiple selection."
        end

        if selection_model.ranges.first.height != arr.size
          raise PasteError, "Height of paste area (#{selection_model.ranges.first.height}) doesn't match height of data (#{arr.size})."
        end

        if selection_model.ranges.first.width != arr.first.size
          raise PasteError, "Width of paste area (#{selection_model.ranges.first.width}) doesn't match width of data (#{arr.first.size})."
        end

        # size is the same, so do the paste
        paste_to_index( selected_index, arr )
      end
    end
  end

  # set all indexes in the selection to the value
  def paste_value_to_selection( value )
    selection_model.selected_indexes.each do |index|
      index.text_value = value
      # save records to db via view, so we get error messages
      save_row( index )
    end

    # notify of changed data
    model.data_changed do |change|
      sorted = selection_model.selected_indexes.sort
      change.top_left = sorted.first
      change.bottom_right = sorted.last
    end
  end

  # Paste an array to the index, replacing whatever is at that index
  # and whatever is at other indices matching the size of the pasted
  # csv array. Create new rows if there aren't enough.
  def paste_to_index( top_left_index, csv_arr )
    csv_arr_size = csv_arr.size
    csv_arr.each_with_index do |row,row_index|
      # append row if we need one
      model.add_new_item if top_left_index.row + row_index >= model.row_count

      row.each_with_index do |field, field_index|
        unless top_left_index.column + field_index >= model.column_count
          # do paste
          cell_index = top_left_index.choppy {|i| i.row += row_index; i.column += field_index }
          emit_status_text( "pasted #{row_index+1} of #{csv_arr_size}")
          begin
            cell_index.text_value = field
          rescue
            puts $!.message
            puts $!.backtrace
            show_error( $!.message )
          end
        else
          emit_status_text( "#{pluralize( top_left_index.column + field_index, 'column' )} for pasting data is too large. Truncating." )
        end
      end
      # save records to db via view, so we get error messages
      save_row( top_left_index.choppy {|i| i.row += row_index; i.column = 0 } )
    end

    # make the gui refresh
    model.data_changed do |change|
      change.top_left = top_left_index
      change.bottom_right = top_left_index.choppy do |i|
        i.row += csv_arr.size - 1
        i.column += csv_arr.first.size - 1
      end
    end
  end

end

end
