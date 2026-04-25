# frozen_string_literal: true

class AvitosController < ApplicationController
  include ActionView::RecordIdentifier

  AVITO_API_BASE = "https://api.avito.ru"
  # Как в dizauto: order-management (версия API уточняется в доке Авито при смене)
  ORDERS_PATH = "/order-management/1/orders"

  before_action :set_avito, only: %i[show edit update destroy fetch_orders]

  def index
    @avitos = Avito.all.order(created_at: :desc)
  end

  def show; end

  def new
    @avito = Avito.new
  end

  def edit; end

  def create
    @avito = Avito.new(avito_params)

    respond_to do |format|
      if @avito.save
        format.html { redirect_to avitos_path, notice: t(".created") }
        format.turbo_stream do
          flash[:notice] = t(".created")
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.update(:avitos_actions, partial: "avitos/actions"),
            turbo_stream.append("avitos", partial: "avitos/avito", locals: { avito: @avito })
          ]
        end
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @avito.update(avito_params)
        format.html { redirect_to avitos_path, notice: t(".updated") }
        format.turbo_stream do
          flash[:notice] = t(".updated")
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(dom_id(@avito), partial: "avitos/avito", locals: { avito: @avito })
          ]
        end
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @avito.destroy!

    respond_to do |format|
      format.html { redirect_to avitos_path, notice: t(".destroyed") }
      format.turbo_stream do
        flash[:notice] = t(".destroyed")
        render turbo_stream: [
          render_turbo_flash,
          turbo_stream.update(:avitos_actions, partial: "avitos/actions"),
          turbo_stream.remove(dom_id(@avito))
        ]
      end
    end
  end

  # GET /avitos/:id/fetch_orders — тянем заказы с API, только лог в Rails.logger
  def fetch_orders
    fetch_and_log_avito_orders(@avito)

    respond_to do |format|
      format.html { redirect_to avitos_path }
      format.turbo_stream { render turbo_stream: [render_turbo_flash] }
    end
  end

  private

  def set_avito
    @avito = Avito.find(params[:id])
  end

  def avito_params
    params.require(:avito).permit(:title, :api_id, :api_secret, :profileid)
  end

  def fetch_and_log_avito_orders(avito)
    token = request_avito_access_token(avito)
    if token.blank?
      flash[:alert] = t(".fetch_error", message: t(".fetch_no_token"))
      return
    end

    url = "#{AVITO_API_BASE}#{ORDERS_PATH}"
    response = RestClient.get(
      url,
      { Authorization: "Bearer #{token}", "Content-Type" => "application/json" }
    )
    Rails.logger.info(
      "[Avito##{avito.id}] orders_response status=#{response.code} body=#{response.body}"
    )
    flash[:notice] = t(".fetch_success")
  rescue RestClient::ExceptionWithResponse => e
    body = e.http_body
    code = e.http_code
    Rails.logger.error "[Avito##{avito.id}] orders_response error status=#{code} body=#{body}"
    flash[:alert] = t(".fetch_error", message: "#{code}: #{truncate_for_flash(body)}")
  rescue JSON::ParserError, SocketError, StandardError => e
    Rails.logger.error "[Avito##{avito.id}] fetch_orders #{e.class}: #{e.message}"
    flash[:alert] = t(".fetch_error", message: e.message)
  end

  def request_avito_access_token(avito)
    response = RestClient.post(
      "#{AVITO_API_BASE}/token",
      {
        client_id: avito.api_id,
        client_secret: avito.api_secret,
        grant_type: "client_credentials"
      },
      { "Content-Type" => "application/x-www-form-urlencoded" }
    )
    Rails.logger.info(
      "[Avito##{avito.id}] token_response status=#{response.code} body=#{response.body}"
    )
    JSON.parse(response.body)["access_token"]
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error(
      "[Avito##{avito.id}] token error status=#{e.http_code} body=#{e.http_body}"
    )
    nil
  rescue JSON::ParserError, StandardError => e
    Rails.logger.error "[Avito##{avito.id}] token #{e.class}: #{e.message}"
    nil
  end

  def truncate_for_flash(str, n = 200)
    s = str.to_s
    s.length > n ? "#{s[0, n]}…" : s
  end
end
