# Configure Mission Control Jobs to work with our authentication system
Rails.application.configure do
  config.after_initialize do
    # Configure Mission Control Jobs to use our base controller
    MissionControl::Jobs.base_controller_class = "ApplicationController"
  end
end
