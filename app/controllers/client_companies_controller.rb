class ClientCompaniesController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_company
  before_action :set_client_company, only: %i[destroy]

  def new
    @client_company = @company.client_companies.build
    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  def create
    # Для новых компаний просто добавляем в коллекцию без сохранения
    # Сохранение произойдет через nested attributes при сохранении компании
    @client_company = @company.client_companies.build(client_company_params)
    
    # Сохраняем только если компания уже сохранена
    if @company.persisted?
      saved = @client_company.save
    else
      # Для новых компаний просто валидируем
      saved = @client_company.valid?
    end

    respond_to do |format|
      if saved
        format.turbo_stream do
          if @company.persisted?
            render turbo_stream: turbo_close_offcanvas_flash + [
              turbo_stream.append(
                'client_companies',
                partial: "client_companies/client_company",
                locals: { client_company: @client_company, company: @company }
              )
            ]
          else
            # Для новых компаний просто добавляем в список без закрытия offcanvas
            render turbo_stream: [
              turbo_stream.append(
                'client_companies',
                partial: "client_companies/client_company",
                locals: { client_company: @client_company, company: @company }
              )
            ]
          end
        end
        format.html { redirect_to @company, notice: t('.success') }
        format.json { render :show, status: :created, location: @client_company }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @client_company.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    check_destroy = @client_company.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @client_company.errors.full_messages.join(' ')
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@client_company)),
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

  def set_client_company
    # Для удаления используем hash ID из turbo_id_for, если компания не сохранена
    # или реальный ID, если компания сохранена
    if @company.persisted?
      # Пытаемся найти по ID, если не найдено - значит это hash ID для новой записи
      @client_company = @company.client_companies.find_by(id: params[:id]) || ClientCompany.new(id: params[:id])
    else
      # Для новых записей используем hash ID из turbo_id_for
      @client_company = ClientCompany.new(id: params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    @client_company = ClientCompany.new(id: params[:id])
  end

  def client_company_params
    params.require(:client_company).permit(:client_id)
  end
end

