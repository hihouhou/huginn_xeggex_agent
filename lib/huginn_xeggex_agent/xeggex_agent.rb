module Agents
  class XeggexAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description do
      <<-MD
      The Xeggex Agent interacts with Xeggex's api.

      The `type` can be like check_balance.

      `debug` is used for verbose mode.

      `api_key` is needed for endpoints with auth.

      `api_secret` is needed for endpoints with auth.

      `symbol` is needed for queries like get_orders, for example CLO/BTC

      `status` is needed for queries like get_orders and limited to active, filled and cancelled.

      `limit` is needed for queries like get_orders.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "asset": "BTC",
            "name": "Bitcoin",
            "available": "1000.00000000",
            "pending": "0.00000000",
            "held": "0.00000000",
            "assetid": "XXXXXXXXXXXXXXXXXXXXXXXX"
          }

    MD

    def default_options
      {
        'type' => 'check_balance',
        'api_token' => '',
        'api_secret' => '',
        'symbol' => '',
        'status' => 'filled',
        'limit' => '10',
        'debug' => 'false',
        'expected_receive_period_in_days' => '2',
      }
    end

    form_configurable :type, type: :array, values: ['check_balance', 'check_orders']
    form_configurable :api_key, type: :string
    form_configurable :api_secret, type: :string
    form_configurable :symbol, type: :string
    form_configurable :status, type: :array, values: ['active', 'filled', 'cancelled']
    form_configurable :limit, type: :string
    form_configurable :debug, type: :boolean
    form_configurable :expected_receive_period_in_days, type: :string
    def validate_options
      errors.add(:base, "type has invalid value: should be 'check_balance' 'check_orders'") if interpolated['type'].present? && !%w(check_balance check_orders).include?(interpolated['type'])

      errors.add(:base, "status has invalid value: should be 'active' 'filled' 'cancelled'") if interpolated['type'].present? && !%w(active filled cancelled).include?(interpolated['status'])

      unless options['api_key'].present? || !['check_balance', 'check_orders'].include?(options['type'])
        errors.add(:base, "api_key is a required field")
      end

      unless options['api_secret'].present? || !['check_balance', 'check_orders'].include?(options['type'])
        errors.add(:base, "api_secret is a required field")
      end

      unless options['symbol'].present? || !['check_orders'].include?(options['type'])
        errors.add(:base, "symbol is a required field")
      end

      unless options['status'].present? || !['check_orders'].include?(options['type'])
        errors.add(:base, "status is a required field")
      end

      unless options['limit'].present? || !['check_orders'].include?(options['type'])
        errors.add(:base, "limit is a required field")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          log event
          trigger_action
        end
      end
    end

    def check
      trigger_action
    end

    private


    def log_curl_output(code,body)

      log "request status : #{code}"

      if interpolated['debug'] == 'true'
        log "body"
        log body
      end

    end

    def check_orders(xeggex_url_endpoint)

      uri = URI.parse(xeggex_url_endpoint + '/getorders?symbol=' + interpolated['symbol'] + '&status=' + interpolated['status'] + '&limit=' + interpolated['limit'] + '&skip=0')
      request = Net::HTTP::Get.new(uri)
      request.basic_auth("#{interpolated['api_key']}", "#{interpolated['api_secret']}")
      request["Accept"] = "application/json"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log_curl_output(response.code,response.body)

      payload = JSON.parse(response.body)
      payload_memory = payload.dup
      if payload != memory['last_status']
        payload.each do |order|
          found = false
          if interpolated['debug'] == 'true'
            log "order"
            log order
          end
          if !memory['last_status'].nil? and memory['last_status'].present?
            if interpolated['debug'] == 'true'
              log "memory"
              log memory['last_status']
            end
            last_status = memory['last_status']
            last_status.each do |orderbis|
              if order == orderbis
                found = true
              end
              if interpolated['debug'] == 'true'
                log "orderbis"
                log orderbis
                log "found is #{found}!"
              end
            end
          end
          if found == false
            create_event payload: order
          end
        end
      else
        if interpolated['debug'] == 'true'
          log "nothing to compare"
        end
      end
      memory['last_status'] = payload_memory

    end

    def check_balance(xeggex_url_endpoint)

      uri = URI.parse(xeggex_url_endpoint + '/balances')
      request = Net::HTTP::Get.new(uri)
      request.basic_auth("#{interpolated['api_key']}", "#{interpolated['api_secret']}")
      request["Accept"] = "application/json"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log_curl_output(response.code,response.body)

      payload = JSON.parse(response.body)
      payload_memory = payload.dup
      if payload != memory['last_status']
        payload.each do |asset|
          found = false
          if interpolated['debug'] == 'true'
            log "asset"
            log asset
          end
          if !memory['last_status'].nil? and memory['last_status'].present?
            if interpolated['debug'] == 'true'
              log "memory"
              log memory['last_status']
            end
            last_status = memory['last_status']
            last_status.each do |assetbis|
              if asset == assetbis
                found = true
              end
              if interpolated['debug'] == 'true'
                log "assetbis"
                log assetbis
                log "found is #{found}!"
              end
            end
          end
          if found == false
            create_event payload: asset
          end
        end
      else
        if interpolated['debug'] == 'true'
          log "nothing to compare"
        end
      end
      memory['last_status'] = payload_memory

    end
    

    def trigger_action

      xeggex_url_endpoint = 'https://api.xeggex.com/api/v2'
      case interpolated['type']
      when "check_balance"
        check_balance(xeggex_url_endpoint)
      when "check_orders"
        check_orders(xeggex_url_endpoint)
      else
        log "Error: type has an invalid value (#{type})"
      end
    end
  end
end
