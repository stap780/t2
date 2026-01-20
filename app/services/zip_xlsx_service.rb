require 'caxlsx'
require 'zip'
require 'stringio'

class ZipXlsxService
  def initialize(collection, options = {})
    @collection = collection
    @model = options[:model].to_s
    @filename = "#{@model.downcase}.xlsx"
    @template = "#{@model.downcase.pluralize}/index"
    @error_message = 'We have error whith zip create'
    @download_kind = options[:download_kind]
  end

  def call
    compressed_filestream = output_stream
    compressed_filestream.rewind

    blob = ActiveStorage::Blob.create_and_upload!(
      io: compressed_filestream,
      filename: "#{@template.tr('/', '_')}.zip"
    )

    if blob
      [true, blob]
    else
      [false, @error_message]
    end
  rescue StandardError => e
    Rails.logger.error("[ZipXlsxService] #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    [false, e.message]
  end

  private

  def output_stream
    renderer = ActionController::Base.new
    renderer.append_view_path(Rails.root.join('app', 'views'))

    rendered_template = renderer.render_to_string(
      layout: false,
      handlers: [:axlsx],
      formats: [:xlsx],
      template: @template,
      locals: { collection: @collection, download_kind: @download_kind }
    )

    Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry(@filename)
      zos.print rendered_template
    end
  end
end

