# Qt-specific accept/reject. Including class must provide #result
module Clevic
  module AcceptReject
    def accepted?
      [ Qt::Dialog::Accepted, Qt::MessageBox::Yes, Qt::MessageBox::Ok ].include?( result )
    end

    def rejected?
      [ Qt::Dialog::Rejected, Qt::MessageBox::No, Qt::MessageBox::Cancel ].include?( result )
    end
  end
end
