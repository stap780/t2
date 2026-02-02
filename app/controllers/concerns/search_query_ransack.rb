module SearchQueryRansack
  extend ActiveSupport::Concern

  included do
    before_action :search_params
    before_action :clear_search_index, only: [:index]
  end

  private

  # CHECK THE SESSION FOR SEARCH PARAMETERS IS THEY AREN'T IN THE REQUEST
  def search_params
    if params[:q].nil?
      params[:q] = session[search_key]
    end
    if params[:q].present?
      # В сессию кладём только обычный Hash (без ActionController::Parameters),
      # иначе Marshal.dump падает на "can't dump IO" при active_record_store
      raw = params[:q]
      session[search_key] = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
    end
    params[:q]
  end

  # DELETE SEARCH PARAMETERS FROM THE SESSION
  def clear_search_index
    # puts 'clear_search_index'
    # puts "controller_name => #{controller_name.singularize}"
    if params[:search_cancel]
      params.delete(:search_cancel)
      if(!search_params.nil?)
        search_params.each do |key, param|
          search_params[key] = nil
        end
      end
      # REMOVE FROM SESSION
      session.delete(search_key)
    end
  end

  protected

  # GENERATE A GENERIC SESSION KEY BASED ON THE CONTROLLER NAME
  def search_key
    "#{controller_name}_search".to_sym
  end

end

