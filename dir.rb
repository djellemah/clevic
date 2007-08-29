#! /usr/bin/ruby

require 'Qt4'
require 'pp'

class SimpleDirModel < Qt::DirModel
  # return QVariant containing name of column
  def not_headerData( section, orientation, role)
    if ( orientation == Qt::Horizontal )
      if (role != Qt::DisplayRole)
        Qt::Variant.new
      end
      
      if ( section == 0 )
        Qt::Variant.new( tr('Name') )
      else
        Qt::Variant.new
      end
    else
      Qt::AbstractItemModel::headerData(section, orientation, role)
    end
  end
  
  def flags( *args )
    puts args
    Qt::DirModel::flags( args )
  end

  def columnCount( parent )
    1
  end
end

class SimpleTreeView < Qt::TreeView
  def header
    nil
  end
  
  def setHeader
    puts "setHeader"
  end
end

app = Qt::Application.new( ARGV )
pp ARGV
model = SimpleDirModel.new
view = SimpleTreeView.new
view.model = model
view.header = nil
view.show
view.root_index = model.index( ARGV[0] || '.' )
app.exec
