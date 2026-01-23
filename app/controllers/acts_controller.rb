class ActsController < ApplicationController
  before_action :set_act, only: [:show, :edit, :update, :destroy, :print, :print_etiketkas]
  include ActionView::RecordIdentifier
  include PrintEtiketkas

  def index
    @search = Act.includes(:company, :strah, :okrug, :items).ransack(params[:q])
    @search.sorts = "id desc" if @search.sorts.empty?
    @acts = @search.result(distinct: true).paginate(page: params[:page], per_page: 100)
  end

  def show
    # @act уже загружен через before_action :set_act с includes
  end

  def edit
  end

  def update
    respond_to do |format|
      if @act.update(act_params)
        format.html { redirect_to acts_path, notice: t('.success') }
        format.json { render :show, status: :ok, location: @act }
        format.turbo_stream do
          flash.now[:success] = t('.success')
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @act.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    check_destroy = @act.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @act.errors.full_messages.join(' ')
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@act)),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to acts_path, notice: t('.success') }
      format.json { head :no_content }
    end
  end

  def new
    @okrugs = Okrug.order(:position)
    @item_statuses = ItemStatus.order(:position)
  end

  def create_multi
    # Отладочная информация
    Rails.logger.debug "ActsController#create_multi params: #{params.inspect}"
    Rails.logger.debug "okrug_ids: #{params[:okrug_ids].inspect}"
    Rails.logger.debug "item_status_ids: #{params[:item_status_ids].inspect}"
    
    if params[:okrug_ids].present? && params[:item_status_ids].present?
      # Находим заявки компаний из выбранных округов, у которых есть позиции с нужными статусами
      okrug_ids = params[:okrug_ids].map(&:to_i)
      item_status_ids = params[:item_status_ids].map(&:to_i)
      
      Rails.logger.debug "Searching for incases with okrug_ids: #{okrug_ids.inspect}, item_status_ids: #{item_status_ids.inspect}"
      
      # Используем ransack для поиска заявок через связь company -> okrug
      # Сначала находим заявки компаний из выбранных округов
      search_params = { company_okrug_id_in: okrug_ids }
      @search = Incase.includes(:company, :strah, :items, items: :item_status, company: :company_plan_dates)
                      .ransack(search_params)
      incase_ids = @search.result.pluck(:id)
      Rails.logger.debug "Found #{incase_ids.count} incases for selected okrugs"
      
      if incase_ids.empty?
        Rails.logger.debug "No incases found for okrug_ids: #{okrug_ids.inspect}"
        @incases_group_by_company_id = {}
      else
        # Находим позиции с нужными статусами в этих заявках
        item_incase_ids = Item.where(incase_id: incase_ids, item_status_id: item_status_ids).pluck(:incase_id).uniq
        Rails.logger.debug "Found #{item_incase_ids.count} incases with items matching statuses"
        
        @incases = Incase.where(id: item_incase_ids)
          .includes(:company, :strah, :items, items: :item_status, company: :company_plan_dates)
          .order(:company_id)
        
        Rails.logger.debug "Final result: #{@incases.count} incases loaded"
        
        # Группируем по компаниям
        @incases_group_by_company_id = @incases.group_by(&:company_id)
      end
      
      # Вычисляем метаданные для каждой компании (перенос логики из JavaScript)
      @companies_metadata = {}
      now = Date.current
      
      # Определяем ID статусов "Долг" и "В работе"
      dolg_status = ItemStatus.find_by(title: 'Долг')
      vrabote_status = ItemStatus.find_by(title: 'В работе')
      dolg_status_id = dolg_status&.id
      vrabote_status_id = vrabote_status&.id
      
      @incases_group_by_company_id.each do |company_id, incases|
        company = incases.first.company
        
        # Собираем все позиции для этой компании из выбранных заявок
        all_items = incases.flat_map(&:items).select { |item| item_status_ids.include?(item.item_status_id) }
        
        # 1. Количество позиций
        items_quantity = all_items.count
        
        # 2. Количество позиций со статусом "Долг"
        items_dolg = dolg_status_id ? all_items.count { |item| item.item_status_id == dolg_status_id } : 0
        
        # 3. Последняя дата обновления статуса позиций
        last_status_dates = all_items.map { |item| item.updated_at }.compact.sort.reverse
        last_day = last_status_dates.first&.strftime('%d/%m/%Y')
        
        # 4. Вычисление vrday (дни с момента последнего обновления позиций "В работе")
        # Используем audited gem для поиска даты установки статуса "В работе"
        vrabote_dates = []
        if vrabote_status_id
          item_ids_for_vrabote = all_items.select { |item| item.item_status_id == vrabote_status_id }.map(&:id)
          if item_ids_for_vrabote.any?
            # Оптимизированный запрос к аудиту для всех соответствующих items
            audits = Audited::Audit.where(auditable_type: 'Item', auditable_id: item_ids_for_vrabote)
                          .where("audited_changes ? 'item_status_id'")
                          .order(created_at: :asc) # Ищем самое раннее изменение
            
            item_ids_for_vrabote.each do |item_id|
              # Находим первое изменение item_status_id на vrabote_status_id для каждого item
              audit_record = audits.find do |audit|
                next unless audit.auditable_id == item_id
                changes = audit.audited_changes['item_status_id']
                if changes.is_a?(Array)
                  changes[1].to_s == vrabote_status_id.to_s
                else
                  false
                end
              end
              vrabote_dates << audit_record.created_at.to_date if audit_record
            end
          end
        end
        
        # Fallback: если аудит не найден (например, статус установлен при создании), используем item.created_at
        if vrabote_dates.empty? && vrabote_status_id
          all_items.select { |item| item.item_status_id == vrabote_status_id }.each do |item|
            vrabote_dates << item.created_at.to_date
          end
        end
        
        vrday = vrabote_dates.any? ? (now - vrabote_dates.min).to_i : 0
        
        # 5. Вычисление planvalue (разница дней между плановой датой и текущей датой)
        plandate = company.company_plan_dates.last&.date
        planvalue = plandate ? (plandate.to_date - now).to_i : nil
        
        # 6. Определение цветового статуса компании
        incase_status_title = incases.first&.incase_status&.title || incases.first&.incase_tip&.title
        
        status_css, color_id = calculate_company_status(
          plandate: plandate,
          planvalue: planvalue,
          vrday: vrday,
          items_quantity: items_quantity,
          items_dolg: items_dolg,
          incase_status: incase_status_title
        )
        
        @companies_metadata[company_id] = {
          items_quantity: items_quantity,
          items_dolg: items_dolg,
          last_day: last_day,
          vrday: vrday,
          plandate: plandate&.strftime('%d/%m/%Y'),
          planvalue: planvalue,
          status_css: status_css,
          color_id: color_id
        }
      end
      
      # Сохраняем параметры для использования в шаблоне
      @okrug_ids = params[:okrug_ids]
      @item_status_ids = params[:item_status_ids]
      
      respond_to do |format|
        format.html { render :create_multi }
        format.json { render json: { status: "ok", message: "ok" } }
      end
    else
      redirect_to new_act_path, alert: "Выберите округа и статусы позиций"
    end
  end

  def update_multi
    act_datas = params[:act_datas] || {}
    
    result = Act.create_from_selected_items(act_datas)

    respond_to do |format|
      if result[:error]
        format.turbo_stream do
          flash.now[:alert] = result[:message]
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      else
        format.turbo_stream { redirect_to acts_path(format: :html), notice: "Создано актов: #{result[:act_ids]&.count || 0}" }
      end
    end
  end

  def print
    respond_to do |format|
      format.pdf do
        pdf_data = @act.generate_pdf
        send_data pdf_data, filename: "act_#{@act.number}.pdf", type: 'application/pdf', disposition: 'inline'
      end
    end
  end

  # Печать этикеток только для выбранных позиций акта
  def print_selected_etiketkas
    @act = Act.find(params[:id])

    item_ids = params[:item_ids]

    if item_ids.blank?
      flash[:alert] = 'Выберите позиции для печати этикеток'
      redirect_back(fallback_location: act_path(@act))
      return
    end

    # Получаем ID вариантов из выбранных позиций
    variant_ids = Item.where(id: item_ids).pluck(:variant_id).compact.uniq

    if variant_ids.empty?
      flash[:alert] = 'Нет вариантов для печати'
      redirect_back(fallback_location: act_path(@act))
      return
    end

    print_etiketkas_from_variant_ids(
      variant_ids,
      fallback_path: act_path(@act),
      file_identifier: @act.number,
      record_name: 'акте'
    )
  end


  private

  def set_act
    @act = Act.find(params[:id])
  end

  def act_params
    params.require(:act).permit(:status, :date)
  end

  def calculate_company_status(plandate:, planvalue:, vrday:, items_quantity:, items_dolg:, incase_status:)
    # Логика из "Нового варианта расставления цветов" (update_data_after_load_new, строки 142-167)
    # ВАЖНО: Порядок проверок точно соответствует JavaScript коду
    
    new_css = nil
    color_id = nil
    
    # ШАГ 1: Определение цвета по plandate или vrday (строки 146-156)
    # Сначала проверяем plandate, если его нет - используем vrday
    if plandate.present? && planvalue.present?
      # Если есть плановая дата
      if planvalue <= 1
        new_css = 'status-red'
        color_id = 1
      elsif planvalue == 2
        new_css = 'status-yellow'
        color_id = 2
      elsif planvalue > 2
        new_css = 'status-green'
        color_id = 3
      end
    else
      # Если нет плановой даты, используем vrday
      # В JS: if ( vrday != '' ) - проверка на наличие значения
      if vrday.present? && vrday > 0
        if vrday > 5
          new_css = 'status-red'
          color_id = 1
        elsif vrday > 2 && vrday <= 5  # В JS: vrday < 5 && vrday > 2
          new_css = 'status-yellow'
          color_id = 2
        elsif vrday <= 2
          new_css = 'status-green'
          color_id = 3
        end
      end
    end
    
    # ШАГ 2: Если все позиции в статусе "Долг" (qt == dolg) - ПЕРЕЗАПИСЫВАЕТ предыдущий цвет (строки 157-160)
    # В JS: if (qt == dolg) { new_css = 'status-graphite'; colorId = 5; }
    # Это проверка идет ПОСЛЕ определения цвета по plandate/vrday и перезаписывает его
    if items_quantity > 0 && items_quantity == items_dolg
      new_css = 'status-graphite'
      color_id = 5
    end
    
    # ШАГ 3: Если статус убытка "Просрочен" - сбрасываем цвет (строки 161-163)
    # В JS: if (statusUbitka == 'Просрочен') { new_css = undefined }
    # statusUbitka берется из data-statusUbitka атрибута (статус убытка/заявки)
    if incase_status == 'Просрочен'
      new_css = nil
    end
    
    # ШАГ 4: Если цвет не определен, устанавливаем status-white (строки 164-167)
    # В JS: if (new_css == undefined ) { new_css = 'status-white'; colorId = 4; }
    if new_css.nil?
      new_css = 'status-white'
      color_id = 4
    end
    
    [new_css, color_id]
  end

  
end

