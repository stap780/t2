class Incases::CommentsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_incase
  before_action :set_comment, only: %i[destroy]

  def new
    @comment = @incase.comments.build
  end

  def create
    @comment = @incase.comments.build(comment_params)
    @comment.user_id = Current.user&.id if defined?(Current) && Current.user

    respond_to do |format|
      if @comment.save
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.prepend(
              dom_id(@incase, :comments),
              partial: "incases/comments/comment",
              locals: { comment: @comment, incase: @incase }
            )
          ]
        end
        format.html { redirect_to incase_path(@incase), notice: t('.success') }
        format.json { render :show, status: :created, location: @comment }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @comment.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    check_destroy = @comment.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @comment.errors.full_messages.join(' ')
    end
    
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@incase, dom_id(@comment))),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to incase_path(@incase), notice: t('.success') }
      format.json { head :no_content }
    end
  end

  private

  def set_incase
    @incase = Incase.find(params[:incase_id])
  end

  def set_comment
    @comment = @incase.comments.find(params[:id])
  end

  def comment_params
    params.require(:comment).permit(:body, :user_id, :commentable_type, :commentable_id)
  end

  def render_turbo_flash
    turbo_stream.replace("flash", partial: "shared/flash")
  end
end

