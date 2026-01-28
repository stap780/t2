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

    # Для интерфейса проверки дублей:
    # - подсветка дублирующих деталей
    # - предустановленные галочки на недублирующих деталях
    if @existing_incase.present?
      existing_katnumbers = @existing_incase.items.pluck(:katnumber).compact
      @duplicate_item_ids =
        if existing_katnumbers.any?
          @incase_dubl.incase_item_dubls.where(katnumber: existing_katnumbers).pluck(:id)
        else
          []
        end
    else
      @duplicate_item_ids = []
    end
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
      # Добавляем выбранные позиции дубля в существующий убыток
      selected_items.each do |item_dubl|
        existing_incase.items.create!(
          title: item_dubl.title,
          quantity: item_dubl.quantity,
          price: item_dubl.price,
          katnumber: item_dubl.katnumber,
          supplier_code: item_dubl.supplier_code
        )
      end

      # Если у существующего убытка нет суммы, но совпадает номер З/Н,
      # переносим сумму из импортируемого убытка
      if existing_incase.totalsum.blank? &&
         existing_incase.stoanumber.present? &&
         existing_incase.stoanumber == @incase_dubl.stoanumber &&
         @incase_dubl.totalsum.present?
        existing_incase.update!(totalsum: @incase_dubl.totalsum)
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
      # Создаем новый убыток с данными из дубля и вложенными items_attributes,
      # чтобы валидация items_presence сразу видела позиции
      new_incase = Incase.new(
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

      selected_items.each do |item_dubl|
        new_incase.items.build(
          title: item_dubl.title,
          quantity: item_dubl.quantity,
          price: item_dubl.price,
          katnumber: item_dubl.katnumber,
          supplier_code: item_dubl.supplier_code
        )
      end

      new_incase.save!

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

  def update_totalsum
    existing_incase = @incase_dubl.existing_incase

    if existing_incase.blank?
      flash.now[:error] = t('.incase_not_found')
      respond_to do |format|
        format.html { redirect_to incase_dubls_path }
        format.turbo_stream { render turbo_stream: [render_turbo_flash] }
      end
      return
    end

    dubl_total = @incase_dubl.totalsum || @incase_dubl.incase_item_dubls.sum('price * quantity')

    existing_incase.update!(totalsum: dubl_total)

    flash.now[:success] = t('.success')
    respond_to do |format|
      format.html { redirect_to incase_dubl_path(@incase_dubl), notice: t('.success') }
      format.turbo_stream { render turbo_stream: [render_turbo_flash] }
    end
  rescue => e
    Rails.logger.error "Error updating totalsum from dubl: #{e.message}"
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

