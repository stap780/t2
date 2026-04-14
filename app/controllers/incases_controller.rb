class IncasesController < ApplicationController
  before_action :set_incase, only: %i[ show edit update destroy send_email print_etiketkas calc ]
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
    base_relation = Incase.includes([company: :okrug], :strah, :incase_status, :incase_tip, items: :variant)
    search_params_hash = (search_params || {}).dup

    # Process multiple unumber, carnumber, stoanumber search (несколько значений через пробел → точный поиск по массиву)
    processed_params = process_multiple_unumber_search(search_params_hash)
    processed_params = process_multiple_carnumber_search(processed_params)
    processed_params = process_multiple_stoanumber_search(processed_params)
    
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

        date_from = params[:date_from].presence&.to_date
        date_to = params[:date_to].presence&.to_date

        if date_from.present? && date_to.present?
          base_scope = Incase.includes(:company, :strah, items: [:variant, :item_status])
            .where(date: date_from..date_to)
            .order(date: :asc)
          chart_data = IncaseReportService.new(scope: base_scope).chart_data
          @incase = Incase.includes(:strah, items: [:variant, :item_status]).find(@incase.id)
          render turbo_stream: [
            turbo_stream.replace(dom_id(@incase), partial: 'incases/report_row', locals: { incase: @incase, date_from: date_from, date_to: date_to }),
            turbo_stream.replace('report_chart', partial: 'incases/report_chart', locals: { chart_data: chart_data }),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            turbo_stream.replace(dom_id(@incase), partial: 'incases/incase', locals: { incase: @incase }),
            render_turbo_flash
          ]
        end
      end
    end
  end

  def reports
    date_to = params[:date_to].presence&.to_date || Date.current
    date_from = params[:date_from].presence&.to_date || (date_to - 30.days)

    base_scope = Incase.includes(:company, :strah, items: [:variant, :item_status])
      .where(date: date_from..date_to)
      .order(date: :asc)

    @search = base_scope.ransack(params[:q])
    @search.sorts = "date desc" if @search.sorts.empty?
    @incases = @search.result.includes(:company, :strah, items: [:variant, :item_status]).paginate(page: params[:page], per_page: 50)

    service = IncaseReportService.new(scope: base_scope)
    @totals = service.totals rescue { count: 0, priced_count: 0, unpriced_count: 0, totalsum: 0, items_sum: 0, items_sale_sum: 0, strah_amount: 0 }
    @chart_data = service.chart_data
    @date_from = date_from
    @date_to = date_to

    respond_to do |format|
      format.html
      format.json { render json: @chart_data }
    end
  end

  private

  def process_multiple_unumber_search(search_params_hash)
    process_multiple_field_search(search_params_hash, 'unumber_cont', 'unumber_in', 50)
  end

  def process_multiple_carnumber_search(search_params_hash)
    process_multiple_field_search(search_params_hash, 'carnumber_cont', 'carnumber_in', 50)
  end

  def process_multiple_stoanumber_search(search_params_hash)
    process_multiple_field_search(search_params_hash, 'stoanumber_cont', 'stoanumber_in', 50)
  end

  def process_multiple_field_search(search_params_hash, cont_key, in_key, max_length = 50)
    return search_params_hash unless search_params_hash[cont_key].present?

    search_value = search_params_hash[cont_key].to_s.strip

    if search_value.include?(' ')
      parts = search_value.split(/\s+/).map(&:strip).reject(&:blank?)
      if parts.length > 1 && parts.all? { |part| part.length <= max_length }
        search_params_hash.delete(cont_key)
        search_params_hash[in_key] = parts
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

