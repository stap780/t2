module IncaseJsonImporter
  LOGGER = Logger.new(Rails.root.join("log", "incase_json_import.log"))
  
  def self.run(url = nil, email = nil, password = nil, page = 1)
    puts "=" * 60
    puts "Starting Incase import from JSON"
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
      cases = parse_json(json_data)
      puts "✓ Found #{cases.length} cases"
      
      # Process cases
      puts "\n[3/4] Processing cases..."
      stats = process_cases(cases, cookies)
      
      # Summary
      puts "\n[4/4] Summary:"
      puts "=" * 60
      puts "Total cases: #{cases.length}"
      puts "Created: #{stats[:created]}"
      puts "Updated: #{stats[:updated]}"
      puts "Duplicates (dubls): #{stats[:dubls]}"
      puts "Errors: #{stats[:errors]}"
      puts "=" * 60
      
      if stats[:errors] > 0
        puts "\n⚠️  Errors occurred. Check logs for details."
        puts "\nError details:"
        stats[:error_messages].each_with_index do |error_msg, idx|
          puts "  #{idx + 1}. #{error_msg}"
        end
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
      # Try common keys for case arrays
      parsed['cases'] || parsed['inbound_cases'] || parsed['data'] || [parsed]
    else
      raise "Unexpected JSON structure: expected Array or Hash"
    end
  rescue JSON::ParserError => e
    raise "Failed to parse JSON: #{e.message}. Response might be HTML or invalid JSON."
  end
  
  def self.process_cases(cases, cookies = nil)
    stats = {
      created: 0,
      updated: 0,
      dubls: 0,
      errors: 0,
      error_messages: []
    }
    
    # Create a single IncaseImport for tracking all dubls
    system_user = User.first || User.order(:id).first
    import = system_user ? IncaseImport.new(
      user: system_user,
      status: :completed,
      total_rows: cases.length,
      success_count: 0,
      failed_count: 0
    ) : nil
    
    if import
      import.source = 'json_import'
      import.save!
    end
    
    cases.each_with_index do |case_data, index|
      begin
        puts "  Processing case #{index + 1}/#{cases.length}: #{case_data['unumber'] || 'N/A'}"
        
        result = process_case(case_data, import, cookies)
        
        case result[:action]
        when :created
          stats[:created] += 1
          puts "    ✓ Created: #{result[:incase].unumber}"
        when :updated
          stats[:updated] += 1
          puts "    ✓ Updated: #{result[:incase].unumber}"
        when :dubl
          stats[:dubls] += 1
          puts "    ⚠ Duplicate (dubl created): #{result[:incase_dubl].unumber}"
        end
        
      rescue => e
        stats[:errors] += 1
        error_msg = "Case #{index + 1} (#{case_data['unumber'] || 'N/A'}): #{e.class} - #{e.message}"
        stats[:error_messages] << error_msg
        puts "    ❌ Error: #{e.message}"
        Rails.logger.error "Error processing case #{index + 1}: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        LOGGER.error error_msg
      end
    end
    
    stats
  end
  
  def self.process_case(case_data, import = nil, cookies = nil)
    unumber = case_data['unumber']&.strip
    raise "unumber is required" if unumber.blank?
    
    # Find or create companies (try to load by ID if available)
    strah_id = case_data['strah_id'] || case_data['strahcompany_id'] || case_data['strah_company_id']
    company_id = case_data['company_id'] || case_data['kontragent_id']
    
    strah_title = case_data['strah_company'] || case_data['strah'] || case_data['strah_company_title']
    company_title = case_data['company'] || case_data['company_title'] || case_data['kontragent']
    
    strah_company = find_or_create_company(strah_title, 'strah', strah_id, cookies)
    company = find_or_create_company(company_title, 'standart', company_id, cookies)
    
    # Skip if both companies are nil
    if strah_company.nil? && company.nil?
      raise "Both strah_company and company are missing for unumber: #{unumber}"
    end
    
    # Find existing incase by (unumber, stoanumber) with normalization of blank stoanumber
    stoanumber = (case_data['stoanumber'] || case_data['number_z_n_stoa'])&.strip
    existing_incase = Incase.find_by_unumber_and_stoanumber(unumber, stoanumber)
    
    if existing_incase.present?
      # Check for differences
      if has_differences?(existing_incase, case_data, strah_company, company)
        # Create dubl
        incase_dubl = create_incase_dubl(case_data, strah_company, company, import)
        { action: :dubl, incase_dubl: incase_dubl }
      else
        # Update status and tip if provided
        incase_status = find_or_create_incase_status(case_data['status'] || case_data[:status])
        incase_tip = find_or_create_incase_tip(case_data['statustype'] || case_data[:statustype])
        
        update_attrs = {
          incase_status_id: incase_status&.id || existing_incase.incase_status_id,
          incase_tip_id: incase_tip&.id || existing_incase.incase_tip_id,
          modelauto: [case_data['marka'] || case_data['marka_ts'], case_data['model'] || case_data['model_ts']].compact.join(' ').strip.presence || existing_incase.modelauto
        }
        
        # Update totalsum if provided in JSON
        totalsum_from_json = parse_decimal(case_data['totalsum'] || case_data[:totalsum])
        if totalsum_from_json.present?
          update_attrs[:totalsum] = totalsum_from_json
        end
        
        existing_incase.update!(update_attrs)
        
        # Add items if not exists
        add_items_if_not_exists(existing_incase, case_data)
        
        # Recalculate totalsum after adding items (if totalsum wasn't set from JSON)
        unless totalsum_from_json.present?
          existing_incase.save! # This will trigger calculate_totalsum callback
        end
        { action: :updated, incase: existing_incase }
      end
    else
      # Create new incase
      incase = create_new_incase(case_data, strah_company, company)
      { action: :created, incase: incase }
    end
  end
  
  def self.find_or_create_company(title, tip, company_id = nil, cookies = nil)
    # If company_id is provided, try to load from API first
    if company_id.present? && cookies
      company_data = load_company_from_api(company_id, tip, cookies)
      if company_data
        title = company_data['title'] || company_data['short_title'] || title
      end
    end
    
    return nil if title.blank?
    
    Company.find_or_create_by(short_title: title.to_s.strip, tip: tip) do |c|
      c.title = title.to_s.strip
    end
  end
  
  def self.load_company_from_api(company_id, tip, cookies)
    base_url = 'http://138.197.52.153'
    endpoint = tip == 'strah' ? "/strahcompanies/#{company_id}.json" : "/companies/#{company_id}.json"
    url = "#{base_url}#{endpoint}"
    
    begin
      json_data = download_json(url, 5, cookies)
      JSON.parse(json_data)
    rescue => e
      puts "    ⚠️  Failed to load company #{company_id} from API: #{e.message}"
      nil
    end
  end
  
  def self.has_differences?(existing_incase, case_data, strah_company, company)
    parsed_date = parse_date(case_data['actdate'] || case_data['date'] || case_data['created_at'] || case_data['date_vukladki'])
    modelauto = [case_data['marka'] || case_data['marka_ts'], case_data['model'] || case_data['model_ts']].compact.join(' ').strip
    
    # Find status and tip from JSON
    incase_status = find_or_create_incase_status(case_data['status'] || case_data[:status])
    incase_tip = find_or_create_incase_tip(case_data['statustype'] || case_data[:statustype])
    
    existing_incase.date != parsed_date ||
    existing_incase.stoanumber != (case_data['stoanumber'] || case_data['number_z_n_stoa'])&.strip ||
    (company && existing_incase.company_id != company.id) ||
    (strah_company && existing_incase.strah_id != strah_company.id) ||
    existing_incase.carnumber != (case_data['carnumber'] || case_data['gos_number'] || case_data['gos_nomer'])&.strip ||
    existing_incase.modelauto != modelauto ||
    existing_incase.region != case_data['region']&.strip ||
    (incase_status && existing_incase.incase_status_id != incase_status.id) ||
    (incase_tip && existing_incase.incase_tip_id != incase_tip.id) ||
    (!incase_status && existing_incase.incase_status_id.present?) ||
    (!incase_tip && existing_incase.incase_tip_id.present?)
  end
  
  def self.create_incase_dubl(case_data, strah_company, company, import = nil)
    parsed_date = parse_date(case_data['actdate'] || case_data['date'] || case_data['created_at'] || case_data['date_vukladki'])
    modelauto = [case_data['marka'] || case_data['marka_ts'], case_data['model'] || case_data['model_ts']].compact.join(' ').strip
    
    # Use provided import or create one for tracking
    unless import
      system_user = User.first || User.order(:id).first
      raise "No users found in database" unless system_user
      
      import = IncaseImport.new(
        user: system_user,
        status: :completed,
        total_rows: 1,
        success_count: 0,
        failed_count: 0
      )
      import.source = 'json_import'
      import.save!
    end
    
    # Note: IncaseDubl doesn't have status/tip fields, so we skip them here
    # If needed, these fields should be added to the IncaseDubl model and migration
    incase_dubl = import.incase_dubls.create!(
      region: case_data['region']&.strip,
      strah_id: strah_company&.id,
      stoanumber: (case_data['stoanumber'] || case_data['number_z_n_stoa'])&.strip,
      unumber: case_data['unumber']&.strip,
      company_id: company&.id,
      carnumber: (case_data['carnumber'] || case_data['gos_number'] || case_data['gos_nomer'])&.strip,
      date: parsed_date,
      modelauto: modelauto,
      totalsum: parse_decimal(case_data['totalsum'] || case_data['summa_zapchastey']) || 0
    )
    
    # Create items - check both 'items' and 'inbound_case_items'
    items_data = case_data['inbound_case_items'] || case_data['items']
    
    if items_data.present? && items_data.is_a?(Array)
      items_data.each do |item_data|
        item_hash = item_data.is_a?(Hash) ? item_data : {}
        
        # Note: IncaseItemDubl doesn't have status field, so we skip it here
        # If needed, this field should be added to the IncaseItemDubl model and migration
        incase_dubl.incase_item_dubls.create!(
          title: item_hash['detalname'] || item_hash[:detalname] || item_hash['title'] || item_hash[:title] || item_hash['name'] || item_hash[:name] || '',
          quantity: parse_integer(item_hash['quantity'] || item_hash['item_qt'] || item_hash[:quantity] || item_hash[:item_qt]) || 1,
          price: parse_decimal(item_hash['price'] || item_hash['item_price'] || item_hash['summa_zapchastey'] || item_hash[:price] || item_hash[:item_price] || item_hash[:summa_zapchastey]) || 0,
          katnumber: item_hash['katnumber'] || item_hash[:katnumber] || item_hash['sku'] || item_hash[:sku] || '',
          supplier_code: item_hash['supplier_code'] || item_hash[:supplier_code] || item_hash['kod_postavshika'] || item_hash[:kod_postavshika] || ''
        )
      end
    end
    
    incase_dubl
  end
  
  def self.add_items_if_not_exists(incase, case_data)
    items_data = case_data['inbound_case_items'] || case_data['items']
    return unless items_data.present? && items_data.is_a?(Array)
    
    items_data.each do |item_data|
      item_hash = item_data.is_a?(Hash) ? item_data : {}
      
      # Use detalname as unique identifier if katnumber is not available
      detalname = (item_hash['detalname'] || item_hash[:detalname])&.strip
      katnumber = (item_hash['katnumber'] || item_hash[:katnumber] || item_hash['sku'] || item_hash[:sku])&.strip
      
      # Check if item already exists
      existing_item = if katnumber.present?
        incase.items.find_by(katnumber: katnumber)
      elsif detalname.present?
        incase.items.find_by(title: detalname)
      end
      
      next if existing_item.present?
      
      # Find or create item status
      item_status = find_or_create_item_status(item_hash['status'] || item_hash[:status])
      barcode = (item_hash['barcode'] || item_hash[:barcode])&.strip
      variant_id = find_variant_id_by_barcode(barcode)

      attrs = {
        title: detalname || item_hash['title'] || item_hash[:title] || item_hash['name'] || item_hash[:name] || '',
        quantity: parse_integer(item_hash['quantity'] || item_hash['item_qt'] || item_hash[:quantity] || item_hash[:item_qt]) || 1,
        price: parse_decimal(item_hash['price'] || item_hash['item_price'] || item_hash['summa_zapchastey'] || item_hash[:price] || item_hash[:item_price] || item_hash[:summa_zapchastey]) || 0,
        katnumber: katnumber || '',
        supplier_code: item_hash['supplier_code'] || item_hash[:supplier_code] || item_hash['kod_postavshika'] || item_hash[:kod_postavshika] || '',
        item_status_id: item_status&.id
      }
      attrs[:variant_id] = variant_id if variant_id.present?
      incase.items.create!(attrs)
    end
  end
  
  def self.find_or_create_incase_status(status_title)
    return nil if status_title.blank?
    
    IncaseStatus.find_or_create_by(title: status_title.to_s.strip) do |s|
      # Status is created with default position from acts_as_list
    end
  end
  
  def self.find_or_create_incase_tip(statustype_title)
    return nil if statustype_title.blank?
    
    IncaseTip.find_or_create_by(title: statustype_title.to_s.strip) do |t|
      # Tip is created with default position from acts_as_list
    end
  end
  
  def self.find_or_create_item_status(status_title)
    return nil if status_title.blank?
    
    ItemStatus.find_or_create_by(title: status_title.to_s.strip) do |s|
      # Status is created with default position from acts_as_list
    end
  end

  # Найти вариант по штрихкоду для связывания позиции убытка с товаром
  def self.find_variant_id_by_barcode(barcode)
    return nil if barcode.blank?
    Variant.find_by(barcode: barcode.to_s.strip)&.id
  end
  
  def self.create_new_incase(case_data, strah_company, company)
    # Try actdate first, then date, created_at, date_vukladki
    parsed_date = parse_date(case_data['actdate'] || case_data['date'] || case_data['created_at'] || case_data['date_vukladki'])
    modelauto = [case_data['marka'] || case_data['marka_ts'], case_data['model'] || case_data['model_ts']].compact.join(' ').strip
    
    # Find or create status and tip
    incase_status = find_or_create_incase_status(case_data['status'] || case_data[:status])
    incase_tip = find_or_create_incase_tip(case_data['statustype'] || case_data[:statustype])
    
    # Prepare items_attributes
    # Try both string and symbol keys
    items_data = case_data['inbound_case_items'] || case_data[:inbound_case_items] || case_data['items'] || case_data[:items]
    items_attributes = []
    
    # Debug: check what keys are available
    if items_data.nil? || (items_data.is_a?(Array) && items_data.empty?)
      available_keys = case_data.keys.grep(/item|detal|case/).join(', ')
      puts "    ⚠️  No items_data found for #{case_data['unumber']}. Available keys with 'item/detal/case': #{available_keys}" if available_keys.present?
    end
    
    if items_data.present? && items_data.is_a?(Array) && items_data.any?
      items_data.each_with_index do |item_data, index|
        # Handle both hash and string keys
        item_hash = item_data.is_a?(Hash) ? item_data : {}
        
        # Use detalname as primary source for title (as per user requirement)
        # Try both string and symbol keys
        title = item_hash['detalname'] || item_hash[:detalname] || item_hash['title'] || item_hash[:title] || item_hash['name'] || item_hash[:name] || ''
        
        # Find or create item status
        item_status = find_or_create_item_status(item_hash['status'] || item_hash[:status])
        barcode = (item_hash['barcode'] || item_hash[:barcode])&.strip
        variant_id = find_variant_id_by_barcode(barcode)

        item_attrs = {
          title: title,
          quantity: parse_integer(item_hash['quantity'] || item_hash[:quantity] || item_hash['item_qt'] || item_hash[:item_qt]) || 1,
          price: parse_decimal(item_hash['price'] || item_hash[:price] || item_hash['item_price'] || item_hash[:item_price] || item_hash['summa_zapchastey'] || item_hash[:summa_zapchastey]) || 0,
          katnumber: item_hash['katnumber'] || item_hash[:katnumber] || item_hash['sku'] || item_hash[:sku] || '', # katnumber may be empty
          supplier_code: item_hash['supplier_code'] || item_hash[:supplier_code] || item_hash['kod_postavshika'] || item_hash[:kod_postavshika] || '',
          item_status_id: item_status&.id
        }
        item_attrs[:variant_id] = variant_id if variant_id.present?
        items_attributes << item_attrs
      end
    else
      # If no items in JSON, create a placeholder item to satisfy validation
      # Try to extract item data from case_data directly (for single-item cases)
      item_status = find_or_create_item_status(case_data['status'] || case_data[:status])
      barcode = (case_data['barcode'] || case_data[:barcode])&.strip
      variant_id = find_variant_id_by_barcode(barcode)

      placeholder_attrs = {
        title: case_data['detalname'] || case_data[:detalname] || case_data['detal'] || case_data[:detal] || case_data['title'] || case_data[:title] || 'Позиция',
        quantity: parse_integer(case_data['kol_vo'] || case_data[:kol_vo] || case_data['quantity'] || case_data[:quantity]) || 1,
        price: parse_decimal(case_data['summa_zapchastey'] || case_data[:summa_zapchastey] || case_data['item_price'] || case_data[:item_price] || case_data['price'] || case_data[:price]) || 0,
        katnumber: case_data['katnumber'] || case_data[:katnumber] || case_data['sku'] || case_data[:sku] || '',
        supplier_code: case_data['supplier_code'] || case_data[:supplier_code] || case_data['kod_postavshika'] || case_data[:kod_postavshika] || '',
        item_status_id: item_status&.id
      }
      placeholder_attrs[:variant_id] = variant_id if variant_id.present?
      items_attributes << placeholder_attrs
    end
    
    # Parse totalsum from JSON if available
    totalsum_from_json = parse_decimal(case_data['totalsum'] || case_data[:totalsum])
    
    # Create incase with items_attributes in one save
    incase = Incase.create!(
      region: case_data['region']&.strip,
      strah_id: strah_company&.id,
      stoanumber: (case_data['stoanumber'] || case_data['number_z_n_stoa'])&.strip,
      unumber: case_data['unumber']&.strip,
      company_id: company&.id,
      carnumber: (case_data['carnumber'] || case_data['gos_number'] || case_data['gos_nomer'])&.strip,
      date: parsed_date,
      modelauto: modelauto,
      incase_status_id: incase_status&.id,
      incase_tip_id: incase_tip&.id,
      items_attributes: items_attributes
    )
    
    # Update totalsum from JSON if provided (after creation, as before_save callback recalculates it)
    # Only update if JSON totalsum is different from calculated one, or if we want to preserve JSON value
    if totalsum_from_json.present? && totalsum_from_json != incase.totalsum
      incase.update_column(:totalsum, totalsum_from_json)
    end
    
    incase
  end
  
  def self.parse_date(date_string)
    return nil if date_string.blank?
    
    if date_string.is_a?(Date) || date_string.is_a?(Time) || date_string.is_a?(DateTime)
      return date_string.to_date
    end
    
    Date.parse(date_string.to_s)
  rescue ArgumentError
    Time.parse(date_string.to_s).to_date
  rescue
    nil
  end
  
  def self.parse_decimal(value)
    return nil if value.blank?
    return value if value.is_a?(Numeric)
    
    value.to_s.gsub(',', '.').to_f
  end
  
  def self.parse_integer(value)
    return nil if value.blank?
    return value if value.is_a?(Integer)
    
    value.to_s.to_i
  end
end

namespace :incase do
  desc "Import incases from JSON URL (default: http://138.197.52.153/inbound_cases.json)"
  task :json_import, [:email, :password, :page] => :environment do |t, args|
    require 'net/http'
    require 'uri'
    require 'json'
    
    base_url = 'http://138.197.52.153/inbound_cases.json'
    page = args[:page] || '1'
    url = "#{base_url}?page=#{page}"
    email = args[:email]
    password = args[:password]
    
    puts "Using URL: #{url}"
    puts "Using email: #{email}" if email
    puts "Using page: #{page}"
    
    IncaseJsonImporter.run(url, email, password, page.to_i)
  end

  desc "Import incases from JSON URL for a range of pages (e.g. 12 to 60)"
  task :json_import_range, [:email, :password, :start_page, :end_page] => :environment do |t, args|
    require 'net/http'
    require 'uri'
    require 'json'
  
    base_url = 'http://138.197.52.153/inbound_cases.json'
    email = args[:email]
    password = args[:password]
    start_page = (args[:start_page] || 1).to_i
    end_page = (args[:end_page] || 1).to_i
  
    (start_page..end_page).each do |page|
      url = "#{base_url}?page=#{page}"
      puts "=== Page #{page} ==="
      IncaseJsonImporter.run(url, email, password, page)
    end
  end  

end

# rails 'incase:json_import[email,password,page]'

