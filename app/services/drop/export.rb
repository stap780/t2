# Liquid Drop for Export template rendering (inspired by Dizauto Drop::Export)
# we can use this drop to render some export data in layout_template in export_service.rb
# the product data we take from item_template in export_service.rb
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
  # def data
  #   @export.data
  # end

  # Provide products access for Liquid templates (alias for data)
  # def products
  #   @export.data
  # end

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
    "Product model (#{@export.data.length} products)"
  end

  def has_data_source
    @export.has_data_source?
  end
end
