class AddTimeToT2 < ActiveRecord::Migration[8.0]
	def change
		add_column :exports, :time, :string
	end
end

