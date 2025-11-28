class CompanyPlanDatesController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_company
  before_action :set_company_plan_date, only: %i[destroy]

  def new
    @company_plan_date = @company.company_plan_dates.build
    @company_plan_date.comments.build if @company_plan_date.comments.empty?
    
    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  def create
    @company_plan_date = @company.company_plan_dates.build(company_plan_date_params)
    
    # Для новых компаний просто валидируем, для существующих - сохраняем
    if @company.persisted?
      saved = @company_plan_date.save
    else
      saved = @company_plan_date.valid?
    end

    respond_to do |format|
      if saved
        format.turbo_stream do
          if @company.persisted?
            render turbo_stream: turbo_close_offcanvas_flash + [
              turbo_stream.append(
                'company_plan_dates',
                partial: "company_plan_dates/company_plan_date",
                locals: { company_plan_date: @company_plan_date, company: @company }
              )
            ]
          else
            # Для новых компаний просто добавляем в список без закрытия offcanvas
            render turbo_stream: [
              turbo_stream.append(
                'company_plan_dates',
                partial: "company_plan_dates/company_plan_date",
                locals: { company_plan_date: @company_plan_date, company: @company }
              )
            ]
          end
        end
        format.html { redirect_to @company, notice: t('.success') }
        format.json { render :show, status: :created, location: @company_plan_date }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @company_plan_date.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    check_destroy = @company_plan_date.destroy ? true : false
    
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @company_plan_date.errors.full_messages.join(' ')
    end
    
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@company_plan_date)),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to @company, notice: t(".success") }
      format.json { head :no_content }
    end
  end

  private

  def set_company
    if params[:company_id].present?
      @company = Company.find(params[:company_id])
    else
      # Для новых записей создаем временный объект
      @company = Company.new
    end
  end

  def set_company_plan_date
    # Для удаления используем hash ID из turbo_id_for, если компания не сохранена
    # или реальный ID, если компания сохранена
    if @company.persisted?
      # Пытаемся найти по ID, если не найдено - значит это hash ID для новой записи
      @company_plan_date = @company.company_plan_dates.find_by(id: params[:id]) || CompanyPlanDate.new(id: params[:id])
    else
      # Для новых записей используем hash ID из turbo_id_for
      @company_plan_date = CompanyPlanDate.new(id: params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    @company_plan_date = CompanyPlanDate.new(id: params[:id])
  end

  def company_plan_date_params
    params.require(:company_plan_date).permit(
      :date,
      comments_attributes: [:id, :body, :commentable_type, :commentable_id, :_destroy]
    )
  end
end

