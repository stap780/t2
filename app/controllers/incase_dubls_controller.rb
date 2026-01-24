class IncaseDublsController < ApplicationController
  include ActionView::RecordIdentifier
  
  before_action :set_incase_dubl, only: %i[show merge merge_to_existing merge_to_new destroy]
  
  def index
    @search = IncaseDubl.ransack(params[:q])
    @search.sorts = 'created_at desc' if @search.sorts.empty?
    @incase_dubls = @search.result(distinct: true).includes(:incase_import, :strah, :company).paginate(page: params[:page], per_page: 50)
  end
  
  def show
    @existing_incase = @incase_dubl.existing_incase
    @differences = @incase_dubl.differences
  end
  
  def merge
    merge_to_existing
  end
  
  def merge_to_existing
    existing_incase = @incase_dubl.existing_incase
    
    if existing_incase.blank?
      flash.now[:error] = t('.incase_not_found')
      respond_to do |format|
        format.html { redirect_to incase_dubls_path }
        format.turbo_stream { render turbo_stream: [render_turbo_flash] }
      end
      return
    end
    
    selected_item_ids = params[:item_ids] || []
    
    if selected_item_ids.empty?
      flash.now[:error] = t('.no_items_selected')
      respond_to do |format|
        format.html { redirect_to incase_dubl_path(@incase_dubl) }
        format.turbo_stream { render turbo_stream: [render_turbo_flash] }
      end
      return
    end
    
    selected_items = @incase_dubl.incase_item_dubls.where(id: selected_item_ids)
    # Сохраняем количество ДО транзакции, так как после destroy связанные записи удалятся
    items_count = selected_items.count
    
    ActiveRecord::Base.transaction do
      selected_items.each do |item_dubl|
        existing_incase.items.create!(
          title: item_dubl.title,
          quantity: item_dubl.quantity,
          price: item_dubl.price,
          katnumber: item_dubl.katnumber,
          supplier_code: item_dubl.supplier_code
        )
      end
      
      @incase_dubl.destroy
    end
    
    flash.now[:success] = t('.success', count: items_count)
    respond_to do |format|
      format.html { redirect_to incase_dubls_path, notice: t('.success', count: items_count) }
      format.turbo_stream do
        render turbo_stream: [
          render_turbo_flash,
          turbo_stream.remove(dom_id(@incase_dubl))
        ]
      end
    end
  rescue => e
    Rails.logger.error "Error merging incase dubl: #{e.message}"
    flash.now[:error] = t('.error', message: e.message)
    respond_to do |format|
      format.html { redirect_to incase_dubl_path(@incase_dubl) }
      format.turbo_stream { render turbo_stream: [render_turbo_flash] }
    end
  end
  
  def merge_to_new
    selected_item_ids = params[:item_ids] || []
    
    if selected_item_ids.empty?
      flash.now[:error] = t('.no_items_selected')
      respond_to do |format|
        format.html { redirect_to incase_dubl_path(@incase_dubl) }
        format.turbo_stream { render turbo_stream: [render_turbo_flash] }
      end
      return
    end
    
    selected_items = @incase_dubl.incase_item_dubls.where(id: selected_item_ids)
    items_count = selected_items.count
    
    ActiveRecord::Base.transaction do
      # Создаем новый убыток с данными из дубля
      new_incase = Incase.create!(
        region: @incase_dubl.region,
        strah_id: @incase_dubl.strah_id,
        stoanumber: @incase_dubl.stoanumber,
        unumber: @incase_dubl.unumber,
        company_id: @incase_dubl.company_id,
        carnumber: @incase_dubl.carnumber,
        date: @incase_dubl.date,
        modelauto: @incase_dubl.modelauto,
        totalsum: @incase_dubl.totalsum
      )
      
      # Добавляем выбранные детали в новый убыток
      selected_items.each do |item_dubl|
        new_incase.items.create!(
          title: item_dubl.title,
          quantity: item_dubl.quantity,
          price: item_dubl.price,
          katnumber: item_dubl.katnumber,
          supplier_code: item_dubl.supplier_code
        )
      end
      
      @incase_dubl.destroy
    end
    
    flash.now[:success] = t('.success_new', count: items_count)
    respond_to do |format|
      format.html { redirect_to incase_dubls_path, notice: t('.success_new', count: items_count) }
      format.turbo_stream do
        render turbo_stream: [
          render_turbo_flash,
          turbo_stream.remove(dom_id(@incase_dubl))
        ]
      end
    end
  rescue => e
    Rails.logger.error "Error creating new incase from dubl: #{e.message}"
    flash.now[:error] = t('.error', message: e.message)
    respond_to do |format|
      format.html { redirect_to incase_dubl_path(@incase_dubl) }
      format.turbo_stream { render turbo_stream: [render_turbo_flash] }
    end
  end
  
  def destroy
    @incase_dubl.destroy
    
    respond_to do |format|
      format.html { redirect_to incase_dubls_path, notice: t('.success') }
      format.turbo_stream do
        flash.now[:success] = t('.success')
        render turbo_stream: [
          render_turbo_flash,
          turbo_stream.remove(dom_id(@incase_dubl))
        ]
      end
    end
  end
  
  private
  
  def set_incase_dubl
    @incase_dubl = IncaseDubl.find(params[:id])
  end
end

