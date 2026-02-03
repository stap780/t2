class CompaniesController < ApplicationController
  before_action :set_company, only: %i[show edit update destroy]
  include ActionView::RecordIdentifier
  include SearchQueryRansack
  include DownloadExcel
  include BulkDelete

  def index
    @search = Company.ransack(search_params)
    @search.sorts = 'id desc' if @search.sorts.empty?
    @companies = @search.result(distinct: true).paginate(page: params[:page], per_page: 100)
  end

  def show; end

  def new
    @company = Company.new
  end

  def edit; end

  def search
    if params[:title].present?
      @search_results = Company.ransack(short_title_cont: params[:title]).result
        .limit(20)
        .map { |company| { title: company.short_title, id: company.id } }
        .reject(&:blank?)
      render json: @search_results, status: :ok
    else
      render json: [], status: :ok
    end
  end

  def create
    @company = Company.new(company_params)
    respond_to do |format|
      if @company.save
        format.html { redirect_to companies_url, notice: t(".success") }
        format.json { render :show, status: :created, location: @company }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @company.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @company.update(company_params)
        format.html { redirect_to companies_url, notice: t(".success") }
        format.json { render :show, status: :ok, location: @company }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @company.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    destroyed = @company.destroy
    respond_to do |format|
      format.turbo_stream do
        if destroyed
          flash.now[:success] = t('.success')
          render turbo_stream: [
            turbo_stream.remove(dom_id(@company)),
            render_turbo_flash
          ]
        else
          flash.now[:error] = @company.errors.full_messages.join(' ')
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html do
        if destroyed
          redirect_to companies_url, notice: t('.success')
        else
          redirect_to companies_url, alert: @company.errors.full_messages.join(' ')
        end
      end
      format.json { head :no_content }
    end
  end

  private

  def set_company
    @company = Company.find(params[:id])
  end

  def company_params
    params.require(:company).permit(:tip, :inn, :kpp, :title, :short_title, :ur_address, :fact_address, :ogrn, :okpo, :bik, :bank_title, :bank_account, :info, :okrug_id, weekdays: [],
      client_companies_attributes: [:id, :client_id, :company_id, :_destroy],
      company_plan_dates_attributes: [
        :id, 
        :date, 
        :company_id, 
        :_destroy,
        comments_attributes: [
          :id, 
          :body, 
          :commentable_type, 
          :commentable_id, 
          :_destroy
        ]
      ])
  end

end

