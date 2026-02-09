class IncasesController < ApplicationController
  before_action :set_incase, only: %i[ show edit update destroy act send_email print_etiketkas calc ]
  include ActionView::RecordIdentifier
  include SearchQueryRansack
  include DownloadExcel
  include BulkDelete
  include BulkStatus
  include PrintEtiketkas

  def index
    if search_params.present?
      puts "search_params: #{search_params}"
    end
    # Join items and variants if searching by items_barcode
    base_relation = Incase.includes(:company, :strah, :incase_status, :incase_tip, items: :variant)
    search_params_hash = (search_params || {}).dup

    # Process multiple unumber search
    processed_params = process_multiple_unumber_search(search_params_hash)
    
    searching_by_barcode = processed_params.keys.any? { |key| key.to_s.include?('items_barcode') }
    
    # Use left_joins instead of joins to avoid type conflicts with string foreign keys
    # Join variants for barcode search (ransacker in Item needs variant table)
    if searching_by_barcode
      base_relation = base_relation.left_joins(items: :variant)
    end
    @search = base_relation.ransack(processed_params)
    @search.sorts = "date desc" if @search.sorts.empty?
    @incases = @search.result(distinct: true).paginate(page: params[:page], per_page: 100)
  end

  def show
    # @incase = Incase.includes(:company, :strah, :incase_status, :incase_tip, :items, :comments).find(params[:id])
    redirect_to edit_incase_path(@incase)
  end

  def new
    @incase = Incase.new
    @incase.items.build
    @incase.comments.build
  end

  def edit
    @incase.items.build if @incase.items.empty?
  end

  def filter
    # Join items and variants if searching by items_barcode
    base_relation = Incase.includes(:company, :strah, :incase_status, :incase_tip, items: :variant)
    search_params_hash = search_params || {}
    searching_by_barcode = search_params_hash.keys.any? { |key| key.to_s.include?('items_barcode') }
    
    # Use left_joins instead of joins to avoid type conflicts with string foreign keys
    # Join variants for barcode search (ransacker in Item needs variant table)
    if searching_by_barcode
      base_relation = base_relation.left_joins(items: :variant)
    end
    @search = base_relation.ransack(search_params)
    @search.sorts = "id desc" if @search.sorts.empty?
    @incases = @search.result(distinct: true).paginate(page: params[:page], per_page: 100)
  end

  def create
    @incase = Incase.new(incase_params)
    respond_to do |format|
      if @incase.save
        format.html { redirect_to incases_path, notice: t(".success") }
        format.json { render :show, status: :created, location: @incase }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @incase.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @incase.update(incase_params)
        format.html { redirect_to incases_path, notice: t(".success") }
        format.json { render :show, status: :ok, location: @incase }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @incase.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    check_destroy = @incase.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @incase.errors.full_messages.join(' ')
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@incase)),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to incases_path, notice: t('.success') }
      format.json { head :no_content }
    end
  end

  def act
    respond_to do |format|
      format.pdf do
        pdf_data = generate_pdf_for_incase(@incase)
        send_data pdf_data, filename: "act_#{@incase.id}.pdf", type: 'application/pdf', disposition: 'inline'
      end
    end
  end

  def bulk_print
    if params[:incase_ids].blank?
      flash.now[:error] = 'Выберите заявки для печати'
      render turbo_stream: [render_turbo_flash]
      return
    end

    incases = Incase.where(id: params[:incase_ids]).includes(:company, :strah, :items)
    
    if incases.empty?
      flash.now[:error] = 'Заявки не найдены'
      render turbo_stream: [render_turbo_flash]
      return
    end

    require 'zip'
    require 'stringio'

    zip_buffer = StringIO.new
    Zip::OutputStream.write_buffer(zip_buffer) do |zip|
      incases.each do |incase|
        pdf_data = generate_pdf_for_incase(incase)
        zip.put_next_entry("act_#{incase.id}.pdf")
        zip.write(pdf_data)
      end
    end

    zip_buffer.rewind
    send_data zip_buffer.read,
              filename: "incases_#{Time.current.strftime('%Y%m%d_%H%M%S')}.zip",
              type: 'application/zip',
              disposition: 'attachment'
  end

  # Массовая отправка (collection action)
  def send_emails
    if params[:incase_ids].blank?
      redirect_to incases_path, alert: 'Выберите убытки для отправки'
      return
    end

    incase_ids = params[:incase_ids].reject(&:blank?)
    
    if incase_ids.empty?
      redirect_to incases_path, alert: 'Выберите убытки для отправки'
      return
    end

    begin
      IncaseEmailService.send(incase_ids)
      redirect_to incases_path, notice: 'Письма по убыткам отправлены'
    rescue => e
      redirect_to incases_path, alert: "Ошибка при отправке: #{e.message}"
    end
  end

  # Одиночная отправка (member action) - использует Turbo Stream для обновления строки
  def send_email
    begin
      IncaseEmailService.send([@incase.id])
      @incase.reload
      
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = 'Письмо отправлено'
          render turbo_stream: [
            turbo_stream.replace(dom_id(@incase), partial: 'incases/incase', locals: { incase: @incase }),
            render_turbo_flash
          ]
        end
      end
    rescue => e
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = "Ошибка при отправке: #{e.message}"
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
    end
  end
  def calc
    success, message = @incase.item_prices
    notice = message.presence || (success ? 'Проставили цены позициям' : 'Ошибка при проставлении цен позициям')

    respond_to do |format|
      format.html { redirect_to incases_path, notice: notice }
      format.turbo_stream do
        @incase.reload
        flash.now[success ? :notice : :alert] = notice
        render turbo_stream: [
          turbo_stream.replace(dom_id(@incase), partial: 'incases/incase', locals: { incase: @incase }),
          render_turbo_flash
        ]
      end
    end
  end

  private

  def generate_pdf_for_incase(incase)
    pdf = Prawn::Document.new(page_size: 'A4', page_layout: :portrait)
    
    company = incase.company
    strahcompany = incase.strah
    
    # Заголовок документа
    pdf.text "Акт приёма-передачи", size: 18, align: :center, style: :bold
    pdf.text "№ #{incase.id}", size: 14, align: :center
    pdf.move_down 20
    
    # Информация о передающей стороне (страховая компания)
    if strahcompany.present?
      pdf.text "Передающая сторона:", size: 12, style: :bold
      pdf.text strahcompany.title, size: 11 if strahcompany.title.present?
      pdf.text strahcompany.ur_address, size: 10 if strahcompany.ur_address.present?
      pdf.move_down 10
    end
    
    # Информация о принимающей стороне (компания)
    if company.present?
      pdf.text "Принимающая сторона:", size: 12, style: :bold
      pdf.text company.title, size: 11 if company.title.present?
      pdf.text company.ur_address, size: 10 if company.ur_address.present?
      pdf.move_down 15
    end
    
    # Основная информация о заявке
    info_data = [
      ['Номер З/Н', incase.stoanumber || ''],
      ['Транспортное средство', "#{incase.modelauto || ''} (#{incase.carnumber || ''})"],
      ['Номер ВД', "#{incase.unumber || ''} от #{incase.date&.strftime('%d.%m.%Y') || ''}"],
      ['Регион', incase.region || ''],
      ['Дата заявки', incase.date&.strftime('%d.%m.%Y') || '']
    ]
    
    pdf.table(info_data, header: false, column_widths: [150, 350]) do
      columns(0).font_style = :bold
      columns(0).background_color = 'F0F0F0'
    end
    
    pdf.move_down 15
    
    # Таблица с позициями заявки
    if incase.items.any?
      pdf.text "Позиции заявки:", size: 12, style: :bold
      pdf.move_down 5
      
      items_data = [['№', 'Название', 'Каталожный номер', 'Количество', 'Цена', 'Сумма']]
      
      incase.items.each_with_index do |item, index|
        items_data << [
          (index + 1).to_s,
          item.title || '',
          item.katnumber || '',
          item.quantity.to_s,
          item.price.to_s,
          item.sum.to_s
        ]
      end
      
      # Добавляем итоговую строку
      items_data << ['', '', '', '', 'Итого:', incase.totalsum.to_s]
      
      pdf.table(items_data, header: true, column_widths: [30, 200, 100, 70, 70, 80]) do
        row(0).font_style = :bold
        row(0).background_color = 'E0E0E0'
        columns(0).align = :center
        columns(3..5).align = :right
        row(items_data.length - 1).font_style = :bold
        row(items_data.length - 1).background_color = 'F0F0F0'
      end
    end
    
    pdf.move_down 30
    
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

  def process_multiple_unumber_search(search_params_hash)
    # В params[:q] ключи приходят строками, не символами.
    # Поле поиска по номеру убытка и др. сейчас называется:
    #   unumber_or_items_barcode_or_carnumber_cont
    search_key = 'unumber_or_items_barcode_or_carnumber_cont'

    return search_params_hash unless search_params_hash[search_key].present?

    search_value = search_params_hash[search_key].to_s.strip

    # Если введено несколько значений через пробел — пытаемся поискать по массиву номеров убытков
    if search_value.include?(' ')
      parts = search_value.split(/\s+/).map(&:strip).reject(&:blank?)

      if parts.length > 1 && parts.all? { |part| part.length <= 50 }
        # Переключаемся с общего поля поиска на точный поиск по массиву unumber
        search_params_hash.delete(search_key)
        search_params_hash['unumber_in'] = parts
      end
    end

    search_params_hash
  end

  def set_incase
    @incase = Incase.find(params[:id])
  end

  def incase_params
    params.require(:incase).permit(
      :region, :sendstatus, :strah_id, :stoanumber, :unumber, :company_id, :carnumber, 
      :date, :modelauto, :totalsum, :incase_status_id, :incase_tip_id,
      items_attributes: [:id, :variant_id, :title, :quantity, :katnumber, 
                         :price, :sum, :item_status_id, :vat, :supplier_code, :_destroy],
      comments_attributes: [:id, :body, :user_id, :commentable_type, :commentable_id, :_destroy]
    )
  end
end

