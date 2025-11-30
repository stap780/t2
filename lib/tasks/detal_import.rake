module DetalJsonImporter
  
  # Маппинг полей JSON на названия свойств (Property)
  PROPERTY_MAPPING = {
    'markamodel' => 'Марка',
    'model' => 'Модель',
    'dtype' => 'Тип диска',
    'diametr' => 'Диаметр',
    'shob' => 'Ширина обода',
    'kotv' => 'К-во отверстий',
    'dotv' => 'Диаметр отверстий',
    'vilet' => 'Вылет',
    'stupica' => 'Ступица (DIA)',
    'sdiameter' => 'Диаметр, дюймы',
    'stype' => 'Сезонность шин',
    'swidth' => 'Ширина профиля шины',
    'sratio' => 'Высота профиля шины',
    'video' => 'Видео',
    'guaranty' => 'Гарантия',
    'material' => 'Материал',
    'avitocat_code' => 'Avito код',
    'analog' => 'Аналог',
    'weight' => 'Вес',
    'avitocat_name' => 'Avito категория',
    'avitotype' => 'Avito тип'
  }.freeze
  
  def self.run(url = nil, email = nil, password = nil, page = 1)
    puts "=" * 60
    puts "Starting Detal import from JSON"
    puts "URL: #{url}"
    puts "=" * 60
    
    cookies = nil
    
    begin
      # Download JSON
      puts "\n[1/4] Downloading JSON..."
      if email && password
        json_data, cookies = authenticate_and_download(url, email, password)
      else
        json_data = download_json(url)
      end
      puts "✓ Downloaded #{json_data.length} bytes"
      
      # Parse JSON
      puts "\n[2/4] Parsing JSON..."
      detals = parse_json(json_data)
      puts "✓ Found #{detals.length} detals"
      
      # Process detals
      puts "\n[3/4] Processing detals..."
      stats = process_detals(detals)
      
      # Summary
      puts "\n[4/4] Summary:"
      puts "=" * 60
      puts "Total detals: #{detals.length}"
      puts "Created: #{stats[:created]}"
      puts "Updated: #{stats[:updated]}"
      puts "Skipped: #{stats[:skipped]}"
      puts "Errors: #{stats[:errors]}"
      puts "=" * 60
      
      if stats[:errors] > 0
        puts "\n⚠️  Errors occurred. Check logs for details."
      else
        puts "\n✓ Import completed successfully!"
      end
      
      stats
    rescue => e
      puts "\n❌ ERROR: #{e.class} - #{e.message}"
      puts e.backtrace.first(10).join("\n")
      raise
    end
  end
  
  def self.download_json(url, limit = 5, cookies = nil)
    raise "Too many redirects" if limit == 0
    
    uri = URI(url)
    base_uri = "#{uri.scheme}://#{uri.host}:#{uri.port}"
    
    Net::HTTP.start(uri.host, uri.port, read_timeout: 30) do |http|
      request = Net::HTTP::Get.new(uri)
      request['Cookie'] = cookies if cookies
      
      response = http.request(request)
      
      case response.code
      when '200'
        response.body
      when '301', '302', '303', '307', '308'
        # Handle redirect
        redirect_url = response['location']
        # Make absolute URL if relative
        redirect_url = URI.join(base_uri, redirect_url).to_s if redirect_url.start_with?('/')
        puts "  Following redirect to: #{redirect_url}"
        
        # Update cookies from response
        new_cookies = update_cookies(cookies, response)
        download_json(redirect_url, limit - 1, new_cookies)
      else
        raise "Failed to download JSON: HTTP #{response.code}"
      end
    end
  end
  
  def self.authenticate_and_download(url, email, password)
    uri = URI(url)
    base_uri = "#{uri.scheme}://#{uri.host}:#{uri.port}"
    
    puts "  Authenticating..."
    
    Net::HTTP.start(uri.host, uri.port, read_timeout: 30) do |http|
      # First, get the login page to get CSRF token and session cookie
      get_request = Net::HTTP::Get.new('/')
      login_response = http.request(get_request)
      
      # Extract CSRF token from the page
      csrf_token = extract_csrf_token(login_response.body)
      cookies = extract_cookies(login_response)
      
      # Prepare login form data (form sends to /sessions with email and password)
      login_data = URI.encode_www_form({
        'email' => email,
        'password' => password,
        'utf8' => '✓'
      })
      login_data += "&authenticity_token=#{csrf_token}" if csrf_token.present?
      
      # Submit login form to /sessions
      post_request = Net::HTTP::Post.new('/sessions')
      post_request['Content-Type'] = 'application/x-www-form-urlencoded'
      post_request['Cookie'] = cookies if cookies
      post_request.body = login_data
      
      login_result = http.request(post_request)
      
      # Update cookies from login response
      cookies = update_cookies(cookies, login_result)
      
      if login_result.code == '302' || login_result.code == '200'
        puts "  ✓ Authentication successful"
        # Now download JSON with authenticated cookies
        json_data = download_json(url, 5, cookies)
        return [json_data, cookies]
      else
        puts "  ⚠️  Login response: HTTP #{login_result.code}"
        puts "  Response body preview: #{login_result.body[0..200]}"
        raise "Authentication failed: HTTP #{login_result.code}"
      end
    end
  end
  
  def self.extract_csrf_token(html)
    # Try to find CSRF token in meta tag or form
    if html =~ /name="csrf-token"\s+content="([^"]+)"/
      $1
    elsif html =~ /name="authenticity_token"\s+value="([^"]+)"/
      $1
    else
      # If no token found, try empty (some apps don't require it)
      ''
    end
  end
  
  def self.extract_cookies(response)
    set_cookies = response.get_fields('Set-Cookie')
    return nil unless set_cookies
    
    set_cookies.map { |cookie| cookie.split(';').first }.join('; ')
  end
  
  def self.update_cookies(existing_cookies, response)
    new_cookies = extract_cookies(response)
    return existing_cookies unless new_cookies
    
    if existing_cookies
      # Merge cookies
      cookie_hash = {}
      existing_cookies.split('; ').each { |c| k, v = c.split('=', 2); cookie_hash[k] = v }
      new_cookies.split('; ').each { |c| k, v = c.split('=', 2); cookie_hash[k] = v }
      cookie_hash.map { |k, v| "#{k}=#{v}" }.join('; ')
    else
      new_cookies
    end
  end
  
  def self.parse_json(json_data)
    # Check if we got HTML instead of JSON (likely a login page)
    if json_data.strip.start_with?('<!DOCTYPE') || json_data.strip.start_with?('<html')
      puts "\n⚠️  WARNING: Received HTML instead of JSON."
      puts "This usually means the URL requires authentication."
      puts "Please check:"
      puts "  1. Is the URL correct?"
      puts "  2. Does it require authentication?"
      puts "  3. Try accessing it in a browser first"
      raise "Received HTML instead of JSON. The URL might require authentication or the endpoint is incorrect."
    end
    
    parsed = JSON.parse(json_data)
    
    # Handle different JSON structures
    case parsed
    when Array
      parsed
    when Hash
      # Try common keys for detal arrays
      parsed['detals'] || parsed['data'] || [parsed]
    else
      raise "Unexpected JSON structure: expected Array or Hash"
    end
  rescue JSON::ParserError => e
    raise "Failed to parse JSON: #{e.message}. Response might be HTML or invalid JSON."
  end
  
  def self.process_detals(detals)
    stats = {
      created: 0,
      updated: 0,
      skipped: 0,
      errors: 0
    }
    
    detals.each_with_index do |detal_data, index|
      begin
        puts "  Processing detal #{index + 1}/#{detals.length}: #{detal_data['sku'] || 'N/A'}"
        
        result = process_detal(detal_data)
        
        case result[:action]
        when :created
          stats[:created] += 1
          puts "    ✓ Created: #{result[:detal].sku} - #{result[:detal].title}"
        when :updated
          stats[:updated] += 1
          puts "    ✓ Updated: #{result[:detal].sku} - #{result[:detal].title}"
        when :skipped
          stats[:skipped] += 1
          puts "    ⊘ Skipped: #{result[:detal].sku} - #{result[:detal].title}"
        end
        
      rescue => e
        stats[:errors] += 1
        puts "    ❌ Error: #{e.message}"
        Rails.logger.error "Error processing detal #{index + 1}: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
      end
    end
    
    stats
  end
  
  def self.process_detal(detal_data)
    sku = detal_data['sku']&.strip
    raise "sku is required" if sku.blank?
    
    # Find or create detal
    detal = Detal.find_or_initialize_by(sku: sku)
    was_new_record = detal.new_record?
    
    # Update basic fields
    detal.title = detal_data['title']&.strip if detal_data['title'].present?
    detal.desc = detal_data['desc']&.strip if detal_data['desc'].present?
    detal.status = detal_data['check'] if detal_data.key?('check')
    
    # Check if detal was changed before saving
    was_changed = detal.changed?
    
    # Save detal first to get ID
    detal.save! if was_changed || was_new_record
    
    # Process features (properties and characteristics)
    process_features(detal, detal_data)
    
    # Determine action
    action = if was_new_record
      :created
    elsif was_changed
      :updated
    else
      :skipped
    end
    
    { action: action, detal: detal }
  end
  
  def self.process_features(detal, detal_data)
    # Process each property mapping
    PROPERTY_MAPPING.each do |json_key, property_title|
      value = detal_data[json_key]&.to_s&.strip
      next if value.blank? # Skip empty values
      
      # Find or create property
      property = Property.find_or_create_by!(title: property_title)
      
      # Find or create characteristic for this property
      characteristic = property.characteristics.find_or_create_by!(title: value)
      
      # Find or create feature (link detal to property and characteristic)
      feature = detal.features.find_or_initialize_by(property_id: property.id)
      feature.characteristic_id = characteristic.id
      feature.save! if feature.changed? || feature.new_record?
    end
  end
end

namespace :detal do
  desc "Import detals from JSON URL (default: http://138.197.52.153/detals.json)"
  task :json_import, [:email, :password, :page] => :environment do |t, args|
    require 'net/http'
    require 'uri'
    require 'json'
    
    base_url = 'http://138.197.52.153/detals.json'
    page = args[:page] || '1'
    url = "#{base_url}?page=#{page}"
    email = args[:email] || 'panaet80@gmail.com'
    password = args[:password] || '071080'
    
    puts "Using URL: #{url}"
    puts "Using email: #{email}" if email
    puts "Using page: #{page}"
    
    DetalJsonImporter.run(url, email, password, page.to_i)
  end
end

#rails 'detal:json_import[email,password,page]'