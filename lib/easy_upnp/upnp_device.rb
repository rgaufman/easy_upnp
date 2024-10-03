# frozen_string_literal: true

require 'uri'
require 'nori'
require 'open-uri'
require 'savon'

require 'easy_upnp/control_point/device_control_point'

module EasyUpnp
  class UpnpDevice
    attr_reader :uuid, :host

    def initialize(uuid, service_definitions)
      @uuid = uuid
      @service_definitions = service_definitions
    end

    def self.from_ssdp_messages(uuid, messages)
      service_definitions = messages.
                            # Filter out messages that aren't service definitions. These include
                            # the root device and the root UUID
                            select { |message| message[:st].include? ':service:' }.
                            # Distinct by ST header -- might have repeats if we sent multiple
                            # M-SEARCH packets
                            group_by { |message| message[:st] }
                                    .map { |_, matching_messages| matching_messages.first }
                                    .map do |message|
        {
          location: message[:location],
            st: message[:st]
        }
      end

      UpnpDevice.new(uuid, service_definitions)
    end

    def host
      @host ||= URI.parse(@service_definitions.first[:location]).host
    end

    def description
      @description ||= fetch_description
    end

    # @deprecated Use {#description['friendlyName']} instead of this method.
    #   It will be removed in the next major release.
    def device_name
      @device_name ||= description['friendlyName']
    end

    def all_services
      @service_definitions.map { |x| x[:st] }
    end

    def service?(urn)
      !service_definition(urn).nil?
    end

    def service(urn, options = {}, &)
      definition = service_definition(urn)

      return if definition.nil?

      DeviceControlPoint.from_service_definition(definition, options, &)
    end

    def service_definition(urn)
      @service_definitions
        .select { |s| s[:st] == urn }
        .first
    end

    private

    # @return [Hash]
    def fetch_description
      raise "Couldn't resolve device description because no endpoints are defined" if all_services.empty?

      location = service_definition(all_services.first)[:location]
      response = Faraday.get(location)
      unless response.success?
        raise "Failed to retrieve data from #{location}: #{response.status} - #{response.reason_phrase}"
      end

      Nori.new.parse(response.body)['root']['device']
    rescue StandardError => e
      logger.error("Error fetching device description: #{e.message}")
      nil
    end
  end
end
