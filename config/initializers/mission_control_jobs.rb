# Configure Mission Control Jobs with authentication
MissionControl::Jobs.base_controller_class = "AuthenticatedJobsController"

Rails.application.configure do
  # Mission Control Jobs will automatically detect Solid Queue
  # Using custom base controller for authentication
end
