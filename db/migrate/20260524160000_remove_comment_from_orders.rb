# frozen_string_literal: true

class RemoveCommentFromOrders < ActiveRecord::Migration[8.1]
  def up
    Order.where.not(comment: [nil, ""]).find_each do |order|
      order.comments.create!(body: order.comment)
    end

    remove_column :orders, :comment
  end

  def down
    add_column :orders, :comment, :text

    Order.find_each do |order|
      body = order.comments.order(created_at: :asc).pick(:body)
      order.update_column(:comment, body) if body.present?
    end
  end
end
