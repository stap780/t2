class DashboardController < ApplicationController
  def index
    # Dashboard for authenticated users
    # Здесь будут графики и статистика
  end

  def fullsearch
    respond_to do |format|
      if params[:query].present?
        @search_results = Dashboard.search(params[:query])
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            'fullsearch_result',
            partial: 'dashboard/search/result'
          )
        end
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            'fullsearch_result',
            partial: 'dashboard/search/result_empty'
          )
        end
      end
      format.html { redirect_to dashboard_path }
    end
  end

end
