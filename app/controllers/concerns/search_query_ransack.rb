module SearchQueryRansack
  extend ActiveSupport::Concern

  protected

  def search_params
    params[:q] || {}
  end
end

