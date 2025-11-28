module CompanyJsonImporter
  
  def self.run(url = nil, email = nil, password = nil, page = 1)
    puts "=" * 60
    puts "Starting Company import from JSON"
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
      companies_data = parse_json(json_data)
      puts "✓ Found #{companies_data.length} companies"
      
      # Process companies
      puts "\n[3/4] Processing companies..."
      stats = process_companies(companies_data, cookies)
      
      # Summary
      puts "\n[4/4] Summary:"
      puts "=" * 60
      puts "Total companies: #{companies_data.length}"
      puts "Created: #{stats[:created]}"
      puts "Updated: #{stats[:updated]}"
      puts "Skipped: #{stats[:skipped]}"
      puts "Clients created: #{stats[:clients_created]}"
      puts "Clients updated: #{stats[:clients_updated]}"
      puts "Client-Company links created: #{stats[:client_company_links]}"
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
      # Try common keys for company arrays
      parsed['companies'] || parsed['data'] || [parsed]
    else
      raise "Unexpected JSON structure: expected Array or Hash"
    end
  rescue JSON::ParserError => e
    raise "Failed to parse JSON: #{e.message}. Response might be HTML or invalid JSON."
  end
  
  def self.process_companies(companies_data, cookies = nil)
    stats = {
      created: 0,
      updated: 0,
      skipped: 0,
      clients_created: 0,
      clients_updated: 0,
      client_company_links: 0,
      errors: 0
    }
    
    companies_data.each_with_index do |company_data, index|
      begin
        company_id = company_data['id']
        company_title = company_data['title']&.strip
        # next unless company_title != 'АвтоГермес Варшавка (w10400, ВРДС00) (Дельта-Сервис)'
    
        puts "  Processing company #{index + 1}/#{companies_data.length}:ID=#{company_id}, Title=#{company_title || 'N/A'}"
        result = process_company(company_data, cookies)
        # puts "result => #{result.inspect}"
        
        case result[:action]
        when :created
          stats[:created] += 1
          puts "    ✓ Created: #{result[:company].short_title} (ID: #{result[:company].id})"
        when :updated
          stats[:updated] += 1
          puts "    ✓ Updated: #{result[:company].short_title} (ID: #{result[:company].id})"
        end
        
        # Update client statistics
        if result[:clients_created]
          stats[:clients_created] += result[:clients_created]
        end
        if result[:clients_updated]
          stats[:clients_updated] += result[:clients_updated]
        end
        if result[:client_company_links]
          stats[:client_company_links] += result[:client_company_links]
        end
        
      rescue => e
        stats[:errors] += 1
        puts "    ❌ Error: #{e.message}"
        puts "      Company ID: #{company_id}, Title: #{company_title || 'N/A'}"
        Rails.logger.error "Error processing company #{index + 1} (ID: #{company_id}, Title: #{company_title}): #{e.message}"
        Rails.logger.error e.backtrace.first(10).join("\n")
      end
    end
    
    stats
  end
  
  def self.process_company(company_data, cookies = nil)
    company_title = company_data['title']&.strip

    short_title = company_title.presence || "Company ##{company_data['id']}"
    
    # Find or create company
    normalized_short_title = short_title.strip

    company = Company.find_by(short_title: normalized_short_title)
    # puts "find => #{company.inspect}"
    company = Company.new(short_title: normalized_short_title) if !company.present?
    
    # Set okrug
    company.okrug = find_or_create_okrug(company_data['okrug']) if company_data['okrug'].present?
    
    # Set title
    company.title = normalized_short_title
    
    # Set weekdays
    if company_data['weekdays'].present? && company_data['weekdays'].is_a?(Array)
      weekday_titles = company_data['weekdays'].map { |w| w['title'] }.compact
      company.weekdays = weekday_titles.map { |title| map_weekday_title_to_key(title) }.compact
    end
    
    # Set info
    info_parts = []
    info_parts << "#{company_data['phone']}" if company_data['phone'].present?
    info_parts << "#{company_data['email']}" if company_data['email'].present?
    info_parts << "#{company_data['address']}" if company_data['address'].present?
    info_parts << "#{company_data['contact']}" if company_data['contact'].present?
    info_parts << "#{company_data['comment']}" if company_data['comment'].present?
    company.info = info_parts.join("\n") if info_parts.any?
    
    # Set default tip for new companies
    company.tip = 'standart' if company.new_record? && company.tip.blank?
    # puts "save => #{company.inspect}"
    # Save company
    company.save!
    action = company.new_record? ? :created : :updated
    
    # Process clients
    clients_stats = process_clients(company_data['clients'], company, cookies) if company_data['clients'].present?
    # puts "clients_stats => #{clients_stats}"
    result = { action: action, company: company }
    result.merge!(clients_stats) if clients_stats
    result
  end
  
  def self.process_clients(clients_data, company, cookies = nil)
    return nil unless clients_data.is_a?(Array)
    
    stats = {
      clients_created: 0,
      clients_updated: 0,
      client_company_links: 0
    }
    
    clients_data.each do |client_data|
      begin
        result = process_client(client_data, company, cookies)
        
        stats[:clients_created] += 1 if result[:action] == :created
        stats[:clients_updated] += 1 if result[:action] == :updated
        stats[:client_company_links] += 1 if result[:link_created]
      rescue => e
        puts "      ⚠️  Error processing client: #{e.message}"
        Rails.logger.error "Error processing client: #{e.message}"
      end
    end
    
    stats
  end
  
  def self.process_client(client_data, company, cookies = nil)
    email = client_data['email']&.strip
    
    # Use default email if email is blank
    email = 'system@mail.esp' if email.blank?
    
    # Find or create client by email
    existing_client = Client.find_by(email: email)
    
    # Prepare client attributes
    # Name is required, use email prefix if name is blank
    name = client_data['name']&.strip
    name = email.split('@').first if name.blank?
    name = 'Client' if name.blank?
    
    client_attributes = {
      email: email,
      name: name,
      surname: client_data['surname']&.strip,
      phone: client_data['phone']&.strip
    }
    
    # Remove nil and empty string values
    client_attributes.delete_if { |k, v| v.nil? || (v.is_a?(String) && v.strip.empty?) }
    
    if existing_client.present?
      # Update existing client
      existing_client.update!(client_attributes)
      client = existing_client
      action = :updated
    else
      # Create new client
      client = Client.create!(client_attributes)
      action = :created
    end
    
    # Create ClientCompany link if it doesn't exist
    link_created = false
    unless ClientCompany.exists?(client_id: client.id, company_id: company.id)
      ClientCompany.create!(client_id: client.id, company_id: company.id)
      link_created = true
    end
    
    { action: action, client: client, link_created: link_created }
  end
  
  def self.find_or_create_okrug(okrug_data)
    return nil unless okrug_data.present?
    
    okrug_title = okrug_data['title']&.strip
    
    return nil if okrug_title.blank?
    
    # Try to find by ID first, then by title
    okrug = Okrug.find_by(title: okrug_title)
    
    if okrug.nil?
      # Create new okrug
      okrug = Okrug.create!(title: okrug_title)
    elsif okrug.title != okrug_title
      # Update title if it changed
      okrug.update!(title: okrug_title)
    end
    
    okrug
  end
  
  def self.load_okrug_from_api(okrug_id, cookies)
    base_url = 'http://138.197.52.153'
    url = "#{base_url}/okrugs/#{okrug_id}.json"
    
    begin
      json_data = download_json(url, 5, cookies)
      JSON.parse(json_data)
    rescue => e
      puts "    ⚠️  Failed to load okrug #{okrug_id} from API: #{e.message}"
      nil
    end
  end
  
  def self.map_weekday_title_to_key(title)
    return nil if title.blank?
    
    # Map Russian weekday names to English keys
    mapping = {
      'Понедельник' => 'monday',
      'Вторник' => 'tuesday',
      'Среда' => 'wednesday',
      'Четверг' => 'thursday',
      'Пятница' => 'friday',
      'Суббота' => 'saturday',
      'Воскресенье' => 'sunday',
      # Also handle case-insensitive and partial matches
      /понедельник/i => 'monday',
      /вторник/i => 'tuesday',
      /среда/i => 'wednesday',
      /четверг/i => 'thursday',
      /пятница/i => 'friday',
      /суббота/i => 'saturday',
      /воскресенье/i => 'sunday'
    }
    
    # Try exact match first
    return mapping[title] if mapping[title]
    
    # Try regex match
    mapping.each do |key, value|
      return value if key.is_a?(Regexp) && title.match?(key)
    end
    
    # If no match found, try to match by English key (in case it's already in English)
    return title.downcase if Company::WEEKDAYS.include?(title.downcase)
    
    puts "      ⚠️  Unknown weekday title: #{title}"
    nil
  end
end

namespace :company do
  desc "Import companies from JSON URL (default: http://138.197.52.153/companies.json)"
  task :json_import, [:email, :password, :page] => :environment do |t, args|
    require 'net/http'
    require 'uri'
    require 'json'
    
    base_url = 'http://138.197.52.153/companies.json'
    page = args[:page] || '1'
    url = "#{base_url}?page=#{page}"
    email = args[:email]
    password = args[:password]
    
    puts "Using URL: #{url}"
    puts "Using email: #{email}" if email
    puts "Using page: #{page}"
    
    CompanyJsonImporter.run(url, email, password, page.to_i)
  end
end

#rails 'company:json_import[email,password,page]'

