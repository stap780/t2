# frozen_string_literal: true

class OrderStatusesController < ApplicationController
  before_action :set_order_status, only: %i[show edit update destroy sort]
  include ActionView::RecordIdentifier

  def index
    @order_statuses = OrderStatus.order(:position)
  end

  def show; end

  def new
    @order_status = OrderStatus.new
  end

  def edit; end

  def create
    @order_status = OrderStatus.new(order_status_params)

    respond_to do |format|
      if @order_status.save
        flash.now[:success] = t(".success")
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              "order_statuses",
              partial: "order_statuses/order_status",
              locals: { order_status: @order_status }
            )
          ]
        end
        format.html { redirect_to order_statuses_path, notice: t(".success") }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "order_status_form",
            partial: "order_statuses/form",
            locals: { order_status: @order_status }
          ), status: :unprocessable_entity
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @order_status.update(order_status_params)
        flash.now[:success] = t(".success")
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(@order_status),
              partial: "order_statuses/order_status",
              locals: { order_status: @order_status }
            )
          ]
        end
        format.html { redirect_to order_statuses_path, notice: t(".success") }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            dom_id(@order_status, :form),
            partial: "order_statuses/form",
            locals: { order_status: @order_status }
          ), status: :unprocessable_entity
        end
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def sort
    position = params[:new_position] || params[:position]
    @order_status.insert_at(position.to_i) if position.present?

    head :ok
  end

  def destroy
    @order_status.destroy!
    flash.now[:success] = t(".success")
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(dom_id(@order_status)),
          render_turbo_flash
        ]
      end
      format.html { redirect_to order_statuses_path, notice: t(".success") }
    end
  end

  private

  def set_order_status
    @order_status = OrderStatus.find(params[:id])
  end

  def order_status_params
    params.require(:order_status).permit(:title, :color, :is_terminal, :position, :code)
  end
end
