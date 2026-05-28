# frozen_string_literal: true

class AvitosController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_avito, only: %i[show edit update destroy fetch_orders sync_catalog]

  def index
    @avitos = Avito.all.order(created_at: :desc)
  end

  def show
    @api_ok = AvitoApi::Auth.access_token(@avito).present?
    @status_mappings = @avito.avito_order_status_mappings.includes(:order_status).order(:id)
    @catalog_synced_count = @avito.catalog_product_bindings_count
  end

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
        AvitoApi::Auth.new(@avito).clear_cache!
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

  # GET /avitos/:id/fetch_orders — импорт заказов в реестр и выгрузка в МС
  def fetch_orders
    stats = AvitoApi::Orders::SyncAccount.call(avito: @avito)

    if stats.errors.include?("no_avito_token")
      flash[:alert] = t(".fetch_error", message: t(".fetch_no_token"))
    elsif stats.errors.any?
      flash[:alert] = t(
        ".fetch_partial",
        imported: stats.imported,
        moysklad_created: stats.moysklad_created,
        errors: AvitoApi::ErrorMessage.translate_list(stats.errors)
      )
    else
      flash[:notice] = t(
        ".fetch_success",
        imported: stats.imported,
        updated: stats.updated,
        skipped: stats.skipped,
        moysklad_created: stats.moysklad_created
      )
    end

    respond_to do |format|
      format.html { redirect_to avito_path(@avito) }
      format.turbo_stream { render turbo_stream: [render_turbo_flash] }
    end
  end

  # GET /avitos/:id/sync_catalog — Varbind Product ↔ avitoId из отчёта автозагрузки
  def sync_catalog
    stats = AvitoApi::Autoload::SyncCatalog.call(avito: @avito)

    if stats.errors.include?("no_avito_token")
      flash[:alert] = t(".sync_error", message: t(".sync_no_token"))
    elsif stats.errors.any?
      flash[:alert] = t(
        ".sync_partial",
        linked: stats.linked,
        existing: stats.existing,
        not_found: stats.not_found,
        conflicts: stats.conflicts,
        errors: AvitoApi::ErrorMessage.translate_list(stats.errors)
      )
    else
      flash[:notice] = t(
        ".sync_success",
        linked: stats.linked,
        existing: stats.existing,
        not_found: stats.not_found,
        skipped: stats.skipped
      )
    end

    respond_to do |format|
      format.html { redirect_to avito_path(@avito, anchor: "avitos_catalog") }
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
end
