load 'clevic/swing/confirm_dialog.rb'

cd = Clevic::ConfirmDialog.new do |dialog|
  dialog.parent = nil
  dialog.question = "What do you want"
  dialog.title = "Your life"
  dialog['Ok'] = :accept, :default
  dialog['Cancel'] = :reject
end
cd.show
