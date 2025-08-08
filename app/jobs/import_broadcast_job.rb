class ImportBroadcastJob < ApplicationJob
  def perform(import)
    case import.status
    when 'completed'
      broadcast_toast(import, "Import '#{import.name}' completed successfully!", 'success')
    when 'failed'
      message = import.has_error? ? 
                "Import '#{import.name}' failed: #{import.error_summary}" :
                "Import '#{import.name}' failed"
      broadcast_toast(import, message, 'error')
    end
  end

  private

  def broadcast_toast(import, message, type)
    # Broadcast toast notification to the user
    ActionCable.server.broadcast(
      "user_#{import.user.id}",
      {
        type: 'toast',
        message: message,
        toast_type: type
      }
    )
  end
end
