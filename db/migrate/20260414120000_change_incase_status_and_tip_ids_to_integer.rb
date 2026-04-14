class ChangeIncaseStatusAndTipIdsToInteger < ActiveRecord::Migration[8.0]
  def up
    cleanup_string_fk_columns

    change_column :incases, :incase_status_id, :integer,
                  using: "CASE WHEN incase_status_id IS NULL OR TRIM(incase_status_id) = '' THEN NULL ELSE incase_status_id::integer END"

    change_column :incases, :incase_tip_id, :integer,
                  using: "CASE WHEN incase_tip_id IS NULL OR TRIM(incase_tip_id) = '' THEN NULL ELSE incase_tip_id::integer END"
  end

  def down
    change_column :incases, :incase_status_id, :string,
                  using: "incase_status_id::text"

    change_column :incases, :incase_tip_id, :string,
                  using: "incase_tip_id::text"
  end

  private

  def cleanup_string_fk_columns
    execute <<~SQL.squish
      UPDATE incases
      SET incase_status_id = NULL
      WHERE incase_status_id IS NOT NULL
        AND (TRIM(incase_status_id) = '' OR incase_status_id !~ '^[0-9]+$')
    SQL

    execute <<~SQL.squish
      UPDATE incases
      SET incase_tip_id = NULL
      WHERE incase_tip_id IS NOT NULL
        AND (TRIM(incase_tip_id) = '' OR incase_tip_id !~ '^[0-9]+$')
    SQL
  end
end