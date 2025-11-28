require 'csv'
require 'fileutils'

class Product::SplitCsvFile
  DEFAULT_FILES_COUNT = 10  # Количество файлов для разделения по умолчанию
  
  def initialize(file_path, file_count: DEFAULT_FILES_COUNT, output_dir: nil)
    @file_path = file_path
    @file_count = file_count
    @output_dir = output_dir || Rails.root.join('tmp', 'csv_imports').to_s
    @split_files = []
  end
  
  def call
    return nil unless File.exist?(@file_path)
    
    ensure_directory_exists
    split
    @split_files
  end
  
  private
  
  def ensure_directory_exists
    FileUtils.mkdir_p(@output_dir) unless Dir.exist?(@output_dir)
  end
  
  def split
    # Разделение CSV на несколько файлов
    header = CSV.foreach(@file_path, headers: false).take(1).flatten
    total_lines = count_lines_in_file(@file_path) - 1  # Минус заголовок
    lines_per_file = (total_lines.to_f / @file_count).ceil
    
    filename = File.basename(@file_path, File.extname(@file_path))
    extension = File.extname(@file_path)
    
    @file_count.times do |i|
      split_file = File.join(@output_dir, "#{filename}-#{i}#{extension}")
      create_split_file(split_file, header, i * lines_per_file, lines_per_file)
      @split_files << split_file
    end
  end
  
  def count_lines_in_file(file_path)
    count = 0
    CSV.foreach(file_path, headers: true) { count += 1 }
    count
  end
  
  def create_split_file(file_path, header, start_line, lines_count)
    CSV.open(file_path, 'wb', headers: false) do |csv|
      csv << header
      CSV.foreach(@file_path, headers: true).with_index do |row, index|
        csv << row if index >= start_line && index < start_line + lines_count
      end
    end
  end
end

