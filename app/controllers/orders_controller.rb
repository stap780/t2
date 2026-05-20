# frozen_string_literal: true

class OrdersController < ApplicationController
  include SearchQueryRansack

  before_action :set_order, only: %i[show export_to_moysklad]

  def index
    @search = Order.includes(:client, :order_status, :avito, :insale).ransack(search_params)
    @search.sorts = "id desc" if @search.sorts.empty?
    @orders = @search.result(distinct: true).paginate(page: params[:page], per_page: 50)
  end

  def show
    @order_items = @order.order_items.includes(variant: :product)
  end

  def export_to_moysklad
    moysklad = Moysklad.first
    unless moysklad
      redirect_to @order, alert: t(".no_moysklad")
      return
    end

    result = MoyskladApi::Orders::CreateFromAppOrder.call(order: @order, moysklad: moysklad)
    if result[:success]
      redirect_to @order, notice: t(".success")
    else
      redirect_to @order, alert: t(".error", message: result[:error])
    end
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end
end
