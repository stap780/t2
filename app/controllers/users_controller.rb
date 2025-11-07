class UsersController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_user, only: [:show, :edit, :update, :destroy]
  before_action :ensure_admin, except: [:index, :show]

  # GET /users
  def index
    @users = User.all.order(created_at: :desc)
  end

  # GET /users/1
  def show
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edit
  def edit
  end

  # POST /users
  def create
    @user = User.new(user_params)

    respond_to do |format|
      if @user.save
        flash[:notice] = t('.created')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append("users", partial: "users/user", locals: { user: @user })
          ]
        end
        format.html { redirect_to @user, notice: t('.created') }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /users/1
  def update
    respond_to do |format|
      if @user.update(user_params)
        flash[:notice] = t('.updated')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(dom_id(@user), partial: "users/user", locals: { user: @user })
          ]
        end
        format.html { redirect_to @user, notice: t('.updated') }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1
  def destroy
    if @user == Current.user
      flash[:alert] = t('.cannot_delete_self')
      redirect_to users_path
      return
    end

    if User.where(role: 'admin').count <= 1 && @user.admin?
      flash[:alert] = t('.cannot_delete_last_admin')
      redirect_to users_path
      return
    end

    @user.destroy!

    respond_to do |format|
      flash[:notice] = t('.destroyed')
      format.html { redirect_to users_path, notice: t('.destroyed') }
      format.turbo_stream do
        render turbo_stream: [
          render_turbo_flash,
          turbo_stream.remove(dom_id(@user))
        ]
      end
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation, :role)
  end
end

