# frozen_string_literal: true

class OrdersController < ApplicationController
  include SearchQueryRansack

  before_action :set_order, only: %i[show export_to_moysklad sync_from_moysklad push_to_insales download_avito_label]

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
      message = case result[:error]
                when "default_ad_source_not_configured" then t(".default_ad_source_not_configured")
                else t(".error", message: result[:error])
                end
      redirect_to @order, alert: message
    end
  end

  def sync_from_moysklad
    moysklad = Moysklad.first
    unless moysklad
      redirect_to @order, alert: t(".no_moysklad")
      return
    end

    result = MoyskladApi::Orders::SyncFromMoysklad.call(order: @order, moysklad: moysklad)
    if result[:success]
      redirect_to @order, notice: t(".success")
    else
      message = case result[:error]
                when "not_linked_to_moysklad" then t(".not_linked_to_moysklad")
                when "moysklad_order_not_found" then t(".moysklad_order_not_found")
                else t(".error", message: result[:error])
                end
      redirect_to @order, alert: message
    end
  end

  def push_to_insales
    result = Insales::Orders::PushFromOrder.call(order: @order)
    if result[:success] && !result[:skipped]
      redirect_to @order, notice: t(".success")
    elsif result[:skipped]
      message = case result[:error]
                when "not_insales_order" then t(".not_insales_order")
                when "no_insales_status_mapping" then t(".no_insales_status_mapping")
                when "nothing_to_push" then t(".nothing_to_push")
                else t(".error", message: result[:error])
                end
      redirect_to @order, alert: message
    else
      message = case result[:error]
                when "insales_order_id_missing" then t(".insales_order_id_missing")
                else t(".error", message: result[:error])
                end
      redirect_to @order, alert: message
    end
  end

  def download_avito_label
    force = ActiveModel::Type::Boolean.new.cast(params[:force])
    result = AvitoApi::Orders::DownloadLabel.call(order: @order, force: force)

    if result.success
      redirect_to @order, notice: t(".success")
    elsif result.skipped
      message = case result.error
                when "not_pvz" then t(".not_pvz")
                when "order_not_found" then t(".order_not_found")
                when "already_attached" then t(".already_attached")
                else t(".error", message: result.error)
                end
      redirect_to @order, alert: message
    else
      message = case result.error
                when "no_token" then t(".no_token")
                when "task_create_failed" then t(".task_create_failed")
                when "label_not_ready" then t(".label_not_ready")
                else t(".error", message: result.error)
                end
      redirect_to @order, alert: message
    end
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end
end
