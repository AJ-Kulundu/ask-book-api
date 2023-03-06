class ChangeDefaultAskCountofQuestion < ActiveRecord::Migration[7.0]
  def change
    change_column_default :questions, :ask_count, from: nil, to: 1
  end
end
