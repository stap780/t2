class ShiftCodesController < ApplicationController
  before_action :set_shift_code, only: %i[edit update destroy]
  include ActionView::RecordIdentifier

  def index
    @shift_codes = ShiftCode.ordered
  end

  def new
    @shift_code = ShiftCode.new
  end

  def edit
  end

  def create
    @shift_code = ShiftCode.new(shift_code_params)

    respond_to do |format|
      if @shift_code.save
        flash.now[:success] = t(".success")
        format.turbo_stream do
          streams = []
          streams << turbo_stream.remove("shift_codes_empty_placeholder") if ShiftCode.one?
          streams += turbo_close_offcanvas_flash + [
            turbo_stream.append(
              "shift_codes",
              partial: "shift_codes/shift_code",
              locals: { shift_code: @shift_code }
            )
          ]
          render turbo_stream: streams
        end
        format.html { redirect_to shift_codes_path, notice: t(".success") }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @shift_code.update(shift_code_params)
        flash.now[:success] = t(".success")
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(@shift_code),
              partial: "shift_codes/shift_code",
              locals: { shift_code: @shift_code }
            )
          ]
        end
        format.html { redirect_to shift_codes_path, notice: t(".success") }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @shift_code.destroy!
    flash.now[:success] = t(".success")
    respond_to do |format|
      format.turbo_stream do
        streams = [turbo_stream.remove(dom_id(@shift_code))]
        streams << turbo_stream.append("shift_codes", partial: "shift_codes/empty_placeholder") if ShiftCode.none?
        streams << render_turbo_flash
        render turbo_stream: streams
      end
      format.html { redirect_to shift_codes_path, notice: t(".success") }
    end
  rescue ActiveRecord::DeleteRestrictionError
    flash.now[:alert] = t(".restrict_error")
    respond_to do |format|
      format.turbo_stream { render turbo_stream: [render_turbo_flash] }
      format.html { redirect_to shift_codes_path, alert: t(".restrict_error") }
    end
  end

  private

  def set_shift_code
    @shift_code = ShiftCode.find(params[:id])
  end

  def shift_code_params
    params.require(:shift_code).permit(:label, :color, :vacation, :day_off)
  end
end
