namespace :product do
  desc "Import products from CSV file"
  task :import => :environment do
    puts "🚀 Starting product import..."
    
    result = ProductService.new.call
    
    if result[:success]
      puts "✅ Import completed successfully!"
      puts "   Created: #{result[:created]}"
      puts "   Updated: #{result[:updated]}"
      puts "   Errors: #{result[:errors]}"
      
      if result[:error_details].present?
        puts "\n⚠️  Error details:"
        result[:error_details].each do |error|
          puts "   - #{error}"
        end
      end
    else
      puts "❌ Import failed: #{result[:error]}"
      puts "   Created: #{result[:created]}"
      puts "   Updated: #{result[:updated]}"
      puts "   Errors: #{result[:errors]}"
    end
  end
end

