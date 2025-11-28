class ActsController < ApplicationController
  before_action :set_act, only: [:show, :edit, :update, :destroy, :act]
  include ActionView::RecordIdentifier

  def index
    @search = Act.includes(:company, :strah, :okrug, :items).ransack(params[:q])
    @search.sorts = "id desc" if @search.sorts.empty?
    @acts = @search.result(distinct: true).paginate(page: params[:page], per_page: 100)
  end

  def show
  end

  def edit
  end

  def update
    respond_to do |format|
      if @act.update(act_params)
        format.html { redirect_to acts_path, notice: t('.success') }
        format.json { render :show, status: :ok, location: @act }
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
    created_act_ids = []
    
    # Группируем позиции по компании, страховой и дате акта (по всем компаниям сразу)
    # ВАЖНО: Группировка должна быть по комбинации company_id + strah_id + date
    items_by_company_strah_and_date = {}
    
    act_datas.each do |company_id, company_data|
      next unless company_data['id'] == '1' # Компания выбрана
      
      company = Company.find(company_id.to_i)
      okrug_id = company.okrug_id
      incases_data = company_data['incases'] || {}
      
      incases_data.each do |incase_id, incase_data|
        next unless incase_data['selected'] == '1' # Заявка выбрана
        
        incase = Incase.find(incase_id.to_i)
        items_data = incase_data['items'] || {}
        
        items_data.each do |item_id, item_data|
          next unless item_data['selected'] == '1' # Позиция выбрана
          
          item = Item.find(item_id.to_i)
          
          # Дата акта = текущая дата (если не выходной, иначе следующий рабочий день)
          act_date = Date.current
          act_date = act_date.advance(days: 1) while act_date.saturday? || act_date.sunday?
          
          # Ключ группировки: компания + страховая + дата
          key = "#{company_id}_#{incase.strah_id}_#{act_date.strftime('%Y-%m-%d')}"
          
          items_by_company_strah_and_date[key] ||= {
            company_id: company_id.to_i,
            strah_id: incase.strah_id,
            date: act_date,
            okrug_id: okrug_id,
            items: []
          }
          items_by_company_strah_and_date[key][:items] << item
        end
      end
    end
    
    # Создаем акты
    items_by_company_strah_and_date.each do |key, data|
      # Ищем существующий акт с такими же параметрами
      existing_act = Act.find_by(
        company_id: data[:company_id],
        strah_id: data[:strah_id],
        date: data[:date],
        status: 'Новый'
      )
      
      if existing_act
        # Добавляем позиции к существующему акту
        data[:items].each do |item|
          ActItem.find_or_create_by!(act: existing_act, item: item)
        end
        created_act_ids << existing_act.id
      else
        # Создаем новый акт
        new_act = Act.create!(
          company_id: data[:company_id],
          strah_id: data[:strah_id],
          okrug_id: data[:okrug_id],
          date: data[:date],
          status: 'Новый',
          number: "#{Time.current.strftime('%Y%m%d')}-#{data[:company_id]}-#{data[:strah_id]}"
        )
        
        # Связываем позиции с актом
        data[:items].each do |item|
          ActItem.create!(act: new_act, item: item)
        end
        created_act_ids << new_act.id
      end
    end
    
    # Генерируем PDF для созданных актов
    if created_act_ids.any?
      redirect_to acts_path(bulk_print_ids: created_act_ids.uniq), 
                  notice: "Создано актов: #{created_act_ids.uniq.count}"
    else
      redirect_to acts_path, alert: "Не выбрано ни одной позиции"
    end
  rescue => e
    Rails.logger.error("update_multi error: #{e.class} #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    redirect_to acts_path, alert: "Ошибка при создании актов: #{e.message}"
  end

  def act
    respond_to do |format|
      format.pdf do
        pdf_data = generate_pdf_for_act(@act)
        send_data pdf_data, filename: "act_#{@act.number}.pdf", type: 'application/pdf', disposition: 'inline'
      end
    end
  end

  def bulk_print
    if params[:act_ids].blank?
      flash.now[:error] = 'Выберите акты для печати'
      render turbo_stream: [render_turbo_flash]
      return
    end

    acts = Act.where(id: params[:act_ids])
    
    if acts.empty?
      flash.now[:error] = 'Акты не найдены'
      render turbo_stream: [render_turbo_flash]
      return
    end

    # Генерируем PDF для каждого акта и создаем ZIP архив
    require 'zip'
    require 'stringio'
    
    zip_buffer = StringIO.new
    Zip::OutputStream.open(zip_buffer) do |zip|
      acts.each do |act|
        pdf_data = generate_pdf_for_act(act)
        zip.put_next_entry("act_#{act.number}.pdf")
        zip.write(pdf_data)
      end
    end
    
    zip_buffer.rewind
    
    send_data zip_buffer.read, 
              filename: "acts_#{Time.current.strftime('%Y%m%d_%H%M%S')}.zip",
              type: 'application/zip',
              disposition: 'attachment'
  end

  private

  def set_act
    @act = Act.find(params[:id])
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

  def generate_pdf_for_act(act)
    require 'prawn'
    
    pdf = Prawn::Document.new(
      page_size: 'A4', 
      page_layout: :portrait,
      margin: [15, 15, 15, 15]
    )
    
    company = act.company
    strahcompany = act.strah
    
    # Шапка: Информация о компании (принимающая сторона)
    pdf.text company.title, size: 14, style: :bold if company&.title.present?
    pdf.text company.ur_address, size: 10 if company&.ur_address.present?
    pdf.move_down 10
    
    # Заголовок акта
    pdf.text "Акт приёма-передачи", size: 18, align: :center, style: :bold
    pdf.text "№ #{act.number}", size: 14, align: :center
    pdf.move_down 15
    
    # Информация о сторонах
    pdf.text "Передающая сторона:", size: 12, style: :bold
    pdf.text strahcompany&.title || '', size: 11
    pdf.text strahcompany&.ur_address || '', size: 10
    pdf.move_down 10
    
    pdf.text "Принимающая сторона:", size: 12, style: :bold
    pdf.text company.title || '', size: 11
    pdf.text company.ur_address || '', size: 10
    pdf.move_down 15
    
    # Дата акта
    pdf.text "г. Москва", size: 10
    pdf.text act.date&.strftime('%d/%m/%Y'), size: 10, align: :right
    pdf.move_down 15
    
    # Текст о передаче
    pdf.text "Передающая сторона передаст Принимающей стороне повреждённые детали, узлы и агрегаты транспортных средств (ТС) в соответствии с нижеперечисленными заказ-нарядами.", size: 10, style: :bold
    pdf.move_down 15
    
    # Группируем позиции по заявкам (Incase)
    # Получаем уникальные заявки из позиций акта
    incases = act.items.includes(:incase).map(&:incase).uniq.compact
    
    incases.each do |incase|
      # Заголовок заявки
      incase_header_data = [
        [
          incase.stoanumber.present? ? "Номер З/Н #{incase.stoanumber}" : "Заявка ##{incase.id}",
          "ТС: #{incase.modelauto || 'Не указано'} (#{incase.carnumber || 'Не указано'})",
          "№ ВД #{incase.unumber} от #{incase.date&.strftime('%d/%m/%Y')}"
        ]
      ]
      
      pdf.table(incase_header_data, header: false, column_widths: [100, 225, 175]) do
        row(0).font_style = :bold
        row(0).background_color = 'E0E0E0'
      end
      
      # Позиции этой заявки, включенные в акт
      act_items_from_incase = act.items.where(incase: incase).order(:title)
      
      act_items_from_incase.each do |item|
        item_data = [
          [
            { content: "#{item.title} (#{item.katnumber})", colspan: 2 },
            { content: "☐ Да ☐ Нет Примечание: #{item.item_status&.title || ''}", colspan: 1 }
          ]
        ]
        
        pdf.table(item_data, header: false, column_widths: [225, 100, 175]) do
          row(0).borders = [:bottom]
          row(0).border_width = 0.5
          row(0).border_color = 'CCCCCC'
        end
      end
      
      pdf.move_down 10
    end
    
    pdf.move_down 20
    
    # Подписи
    pdf.text "Передающая сторона:", size: 10
    pdf.move_down 30
    pdf.text "_________________", size: 10
    pdf.move_down 5
    pdf.text "Принимающая сторона:", size: 10
    pdf.move_down 30
    pdf.text "_________________", size: 10
    
    pdf.render
  end
end

