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
          required_methods = ['PUT', 'POST', 'OPTIONS']
          missing_methods = required_methods - rule.allowed_methods
          if missing_methods.any?
            puts "\n  ⚠️  WARNING: Missing methods for Direct Uploads: #{missing_methods.join(', ')}"
            puts "     Direct Uploads require PUT, POST, and OPTIONS methods!"
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
              <AllowedMethod>OPTIONS</AllowedMethod>
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
  
  desc "Update existing CORS rules to include OPTIONS method"
  task update_cors: :environment do
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
    
    puts "Updating CORS rules for bucket: #{bucket_name}"
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
        # Получаем текущую конфигурацию
        current_cors = s3_client.get_bucket_cors(bucket: bucket_name)
        
        puts "Current CORS rules found: #{current_cors.cors_rules.count}"
        
        # Обновляем правила, добавляя OPTIONS если его нет
        current_cors.cors_rules.each do |rule|
          puts "  Original rule: #{rule.to_h.inspect}"
          
          unless rule.allowed_methods.include?('OPTIONS')
            rule.allowed_methods << 'OPTIONS'
            puts "  → Adding OPTIONS to rule with origins: #{rule.allowed_origins.join(', ')}"
          else
            puts "  ✓ OPTIONS already present in rule with origins: #{rule.allowed_origins.join(', ')}"
          end
          
          if (!rule.allowed_headers || rule.allowed_headers.empty?)
            rule.allowed_headers = ['*']
          end
        end
        
        # Отладочный вывод
        puts "\nUpdated rules structure:"
        current_cors.cors_rules.each_with_index do |rule, idx|
          puts "  Rule #{idx + 1}: #{rule.to_h.inspect}"
        end
        
        # Сохраняем обновленную конфигурацию
        s3_client.put_bucket_cors(
          bucket: bucket_name,
          cors_configuration: {
            cors_rules: current_cors.cors_rules
          }
        )
        
        puts "\n✅ CORS rules updated successfully!"
        puts "Run 'rake timeweb:check_cors' to verify."
        
      rescue Aws::S3::Errors::NoSuchCORSConfiguration
        puts "❌ No CORS configuration found for this bucket!"
        puts "Use 'rake timeweb:set_cors[origin]' to create a new configuration."
      end
      
    rescue => e
      puts "❌ Error updating CORS: #{e.class}: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
  
  desc "Add new CORS rule for localhost:3000 in JSON format. NOTE: OPTIONS method is not supported by Timeweb S3 API - add it manually via panel if needed."
  task add_localhost_rule: :environment do
    require 'aws-sdk-s3'
    require 'yaml'
    require 'json'
    
    allowed_origin = 'http://localhost:3000'
    
    # Читаем конфигурацию из storage.yml
    storage_config = YAML.load_file(Rails.root.join('config', 'storage.yml'))
    service_config = storage_config['timeweb'] || {}
    
    bucket_name = service_config['bucket']
    access_key_id = Rails.application.credentials.dig(:timeweb, :access_key_id)
    secret_access_key = Rails.application.credentials.dig(:timeweb, :secret_access_key)
    endpoint = service_config['endpoint'] || "https://s3.twcstorage.ru"
    region = service_config['region'] || "ru-1"
    
    puts "Adding CORS rule for: #{allowed_origin}"
    puts "Bucket: #{bucket_name}"
    puts "Endpoint: #{endpoint}"
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
      
      # Получаем текущие правила
      existing_rules = []
      begin
        current_cors = s3_client.get_bucket_cors(bucket: bucket_name)
        existing_rules = current_cors.cors_rules.map(&:to_h)
        puts "Found #{existing_rules.count} existing rule(s)"
      rescue Aws::S3::Errors::NoSuchCORSConfiguration
        puts "No existing CORS rules found, creating new configuration"
      end
      
      # Проверяем, есть ли уже правило для localhost:3000
      localhost_rule_exists = existing_rules.any? do |rule|
        rule[:allowed_origins]&.include?(allowed_origin)
      end
      
      if localhost_rule_exists
        puts "⚠️  Rule for #{allowed_origin} already exists!"
        puts "Use 'rake timeweb:check_cors' to view current rules."
        next
      end
      
      # Создаем новое правило в формате JSON (как в документации Timeweb)
      # ВАЖНО: Timeweb S3 может не поддерживать OPTIONS метод
      # Сначала создаем без OPTIONS, потом можно попробовать добавить через панель
      new_rule = {
        allowed_origins: [allowed_origin],
        allowed_methods: ['GET', 'PUT', 'POST', 'DELETE', 'HEAD'],
        allowed_headers: ['*'],
        expose_headers: ['ETag'],
        max_age_seconds: 3000
      }
      
      # Добавляем новое правило к существующим
      all_rules = existing_rules + [new_rule]
      
      # Формируем JSON конфигурацию (как в документации Timeweb)
      cors_json = {
        CORSRules: all_rules.map do |rule|
          {
            AllowedOrigins: rule[:allowed_origins],
            AllowedMethods: rule[:allowed_methods],
            AllowedHeaders: rule[:allowed_headers] || ['*'],
            ExposeHeaders: rule[:expose_headers] || [],
            MaxAgeSeconds: rule[:max_age_seconds] || 3000
          }
        end
      }
      
      puts "\nNew rule to add:"
      puts JSON.pretty_generate(new_rule)
      puts "\nFull CORS configuration (JSON format):"
      puts JSON.pretty_generate(cors_json)
      
      # Конвертируем JSON формат в формат AWS SDK
      cors_config = {
        cors_rules: all_rules
      }
      
      # Сохраняем через API
      s3_client.put_bucket_cors(
        bucket: bucket_name,
        cors_configuration: cors_config
      )
      
      puts "\n✅ CORS rule for #{allowed_origin} added successfully!"
      puts "\n⚠️  IMPORTANT: OPTIONS method is not supported by Timeweb S3 API."
      puts "   To enable preflight requests, add OPTIONS manually via Timeweb panel:"
      puts "   1. Go to S3 bucket settings → CORS"
      puts "   2. Edit the rule for #{allowed_origin}"
      puts "   3. Add OPTIONS to Allowed Methods"
      puts "\nRun 'rake timeweb:check_cors' to verify."
      
    rescue => e
      puts "❌ Error adding CORS rule: #{e.class}: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
end

