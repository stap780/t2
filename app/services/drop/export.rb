# Liquid Drop for Export template rendering (inspired by Dizauto Drop::Export)
class Drop::Export < Liquid::Drop
  def initialize(export)
    @export = export
  end

  def id
    @export.id
  end

  def name
    @export.name
  end

  def format
    @export.format
  end

  # Main data access for Liquid templates
  def data
    @export.data
  end

  # Provide record count for template use
  def record_count
    @export.data.length
  end

  # Export metadata
  def created_at
    @export.created_at
  end

  def exported_at
    @export.exported_at
  end

  # Export status and mode
  def test_mode
    @export.test_mode?
  end

  def status
    @export.status
  end

  # Data source information
  def data_source_info
    @export.data_source_info
  end

  def has_data_source
    @export.has_data_source?
  end
end
