class ClientsController < ApplicationController
  before_action :set_client, only: %i[show edit update destroy]
  include ActionView::RecordIdentifier
  include SearchQueryRansack
  include DownloadExcel
  include BulkDelete

  def index
    @search = Client.ransack(search_params)
    @search.sorts = 'id desc' if @search.sorts.empty?
    @clients = @search.result(distinct: true).paginate(page: params[:page], per_page: 100)
  end

  def show
  end


  def search
    if params[:title].present?
      # Ransack *_cont сам добавляет %...%, поэтому передаём "сырой" title
      @search_results = Client.ransack(name_or_surname_or_email_cont: params[:title]).result.map { |p| {title: p.full_name, id: p.id} }.reject(&:blank?)
      render json: @search_results, status: :ok
    else
      render json: [], status: :unprocessable_entity
    end
  end

  def new
    @client = Client.new
  end

  def edit
  end

  def create
    @client = Client.new(client_params)

    respond_to do |format|
      if @client.save
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              "clients",
              partial: "clients/client",
              locals: { client: @client }
            )
          ]
        end
        format.html { redirect_to clients_url, notice: t('.success') }
        format.json { render :show, status: :created, location: @client }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @client.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @client.update(client_params)
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(@client),
              partial: "clients/client",
              locals: { client: @client }
            )
          ]
        end
        format.html { redirect_to clients_url, notice: t('.success') }
        format.json { render :show, status: :ok, location: @client }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @client.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @check_destroy = @client.destroy ? true : false
    message = if @check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @client.errors.full_messages.join(' ')
    end

    respond_to do |format|
      format.turbo_stream do
        if @check_destroy
          render turbo_stream: [
            turbo_stream.remove(dom_id(@client)),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to clients_url, notice: t('.success') }
      format.json { head :no_content }
    end
  end

  private

  def set_client
    @client = Client.find(params[:id])
  end

  def client_params
    params.require(:client).permit(:surname, :name, :middlename, :phone, :email, :insid)
  end
end

