require 'uri'
require 'nokogiri'
require 'open-uri'
require 'savon'

require 'easy_upnp/control_point/device_control_point'

module EasyUpnp
  class UpnpDevice
    attr_reader :uuid, :name, :host

    def initialize(uuid, service_definitions)
      @uuid = uuid
      @service_definitions = service_definitions
    end

    def self.from_ssdp_messages(uuid, messages)
      service_definitions = messages.
          # Filter out messages that aren't service definitions. These include
          # the root device and the root UUID
          reject { |message| not message[:st].include? ':service:' }.
          # Distinct by ST header -- might have repeats if we sent multiple
          # M-SEARCH packets
          group_by { |message| message[:st] }.
          map { |_, matching_messages| matching_messages.first }.
          map do |message|
            {
                :location => message[:location],
                :st => message[:st]
            }
          end

      UpnpDevice.new(uuid, service_definitions)
    end

    def device_name
      @device_name ||= fetch_device_name
    end

    def all_services
      @service_definitions.map { |x| x[:st] }
    end

    def has_service?(urn)
      !service_definition(urn).nil?
    end

    def service(urn, options = {}, &block)
      definition = service_definition(urn)

      if !definition.nil?
        DeviceControlPoint.from_service_definition(definition, options, &block)
      end
    end

    def service_definition(urn)
      @service_definitions.
          reject { |s| s[:st] != urn }.
          first
    end

    private

    def fetch_device_name
      if all_services.empty?
        raise RuntimeError, "Couldn't resolve device name because no endpoints are defined"
      end

      document = open(service_definition(all_services.first)[:location]) { |f| f.read }
      xml = Nokogiri::XML(document)
      xml.remove_namespaces!

      xml.xpath("//device/friendlyName").text
    end
  end
end
