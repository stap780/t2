namespace :timeweb do
  desc "Check CORS configuration for Timeweb S3 bucket"
  task check_cors: :environment do
    require 'aws-sdk-s3'
    require 'yaml'
    
    # Читаем конфигурацию из storage.yml
    storage_config = YAML.load_file(Rails.root.join('config', 'storage.yml'))
    service_config = storage_config['timeweb'] || {}
    
    bucket_name = service_config['bucket']
    access_key_id = Rails.application.credentials.dig(:timeweb, :access_key_id)
    secret_access_key = Rails.application.credentials.dig(:timeweb, :secret_access_key)
    endpoint = service_config['endpoint'] || "https://s3.twcstorage.ru"
    region = service_config['region'] || "ru-1"
    
    puts "Checking CORS for bucket: #{bucket_name}"
    puts "Endpoint: #{endpoint}"
    puts "Region: #{region}"
    puts "-" * 50
    
    begin
      s3_client = Aws::S3::Client.new(
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        endpoint: endpoint,
        region: region,
        force_path_style: true,
        ssl_verify_peer: false
      )
      
      begin
        cors_config = s3_client.get_bucket_cors(bucket: bucket_name)
        
        puts "CORS configuration found:"
        puts "-" * 50
        
        cors_config.cors_rules.each_with_index do |rule, index|
          puts "\nRule #{index + 1}:"
          puts "  Allowed Origins: #{rule.allowed_origins.join(', ')}"
          puts "  Allowed Methods: #{rule.allowed_methods.join(', ')}"
          puts "  Allowed Headers: #{rule.allowed_headers.join(', ')}" if rule.respond_to?(:allowed_headers) && rule.allowed_headers
          puts "  Exposed Headers: #{rule.exposed_headers.join(', ')}" if rule.respond_to?(:exposed_headers) && rule.exposed_headers
          puts "  Max Age: #{rule.max_age_seconds} seconds" if rule.respond_to?(:max_age_seconds) && rule.max_age_seconds
          
          # Проверка на наличие необходимых методов для Direct Uploads
          required_methods = ['PUT', 'POST']
          missing_methods = required_methods - rule.allowed_methods
          if missing_methods.any?
            puts "\n  ⚠️  WARNING: Missing methods for Direct Uploads: #{missing_methods.join(', ')}"
            puts "     Direct Uploads require PUT and POST methods!"
          end
        end
      rescue Aws::S3::Errors::NoSuchCORSConfiguration
        puts "❌ CORS configuration NOT FOUND for this bucket!"
        puts "You need to configure CORS in Timeweb panel or via API."
        puts "\nExample CORS configuration:"
        puts <<~XML
          <CORSConfiguration>
            <CORSRule>
              <AllowedOrigin>http://localhost:3000</AllowedOrigin>
              <AllowedOrigin>https://your-domain.com</AllowedOrigin>
              <AllowedMethod>PUT</AllowedMethod>
              <AllowedMethod>POST</AllowedMethod>
              <AllowedMethod>GET</AllowedMethod>
              <AllowedMethod>HEAD</AllowedMethod>
              <AllowedHeader>*</AllowedHeader>
              <ExposeHeader>ETag</ExposeHeader>
              <MaxAgeSeconds>3000</MaxAgeSeconds>
            </CORSRule>
          </CORSConfiguration>
        XML
      end
      
    rescue => e
      puts "❌ Error checking CORS: #{e.class}: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
  
  desc "Set CORS configuration for Timeweb S3 bucket"
  task :set_cors, [:allowed_origin] => :environment do |t, args|
    require 'aws-sdk-s3'
    require 'yaml'
    
    allowed_origin = args[:allowed_origin] || 'http://localhost:3000'
    
    # Читаем конфигурацию из storage.yml
    storage_config = YAML.load_file(Rails.root.join('config', 'storage.yml'))
    service_config = storage_config['timeweb'] || {}
    
    bucket_name = service_config['bucket']
    access_key_id = Rails.application.credentials.dig(:timeweb, :access_key_id)
    secret_access_key = Rails.application.credentials.dig(:timeweb, :secret_access_key)
    endpoint = service_config['endpoint'] || "https://s3.twcstorage.ru"
    region = service_config['region'] || "ru-1"
    
    puts "Setting CORS for bucket: #{bucket_name}"
    puts "Allowed Origin: #{allowed_origin}"
    puts "-" * 50
    
    begin
      s3_client = Aws::S3::Client.new(
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        endpoint: endpoint,
        region: region,
        force_path_style: true,
        ssl_verify_peer: false
      )
      
      cors_config = {
        cors_rules: [
          {
            allowed_origins: [allowed_origin, 'https://your-production-domain.com'],
            allowed_methods: ['PUT', 'POST', 'GET', 'HEAD', 'OPTIONS'],
            allowed_headers: ['*'],
            max_age_seconds: 3000
          }
        ]
      }
      
      s3_client.put_bucket_cors(
        bucket: bucket_name,
        cors_configuration: cors_config
      )
      
      puts "✅ CORS configuration set successfully!"
      puts "Run 'rake timeweb:check_cors' to verify."
      
    rescue => e
      puts "❌ Error setting CORS: #{e.class}: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
end

