class CreateCompanyPlanDates < ActiveRecord::Migration[8.0]
  def change
    create_table :company_plan_dates do |t|
      t.references :company, null: false, foreign_key: true
      t.datetime :date

      t.timestamps
    end
  end
end
