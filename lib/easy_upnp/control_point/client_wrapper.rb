# frozen_string_literal: true

module EasyUpnp
  class ClientWrapper
    def initialize(endpoint,
                   urn,
                   call_options,
                   advanced_typecasting,
                   log_enabled,
                   log_level,
                   cookies)

      # For some reason was not able to pass these options in the config block
      # in Savon 2.11
      options = {
        log: log_enabled,
        log_level:
      }

      @client = Savon.client(options) do |c|
        c.endpoint endpoint
        c.namespace urn

        # I found this was necessary on some of my UPnP devices (namely, a Sony TV).
        c.namespaces({ 's:encodingStyle': 'http://schemas.xmlsoap.org/soap/encoding/' })

        # This makes XML tags be like <ObjectID> instead of <objectID>.
        c.convert_request_keys_to :camelcase

        c.namespace_identifier :u
        c.env_namespace :s
      end

      @urn = urn
      @call_options = call_options
      @advanced_typecasting = advanced_typecasting
      @cookies = cookies
    end

    def call(action_name, args)
      attrs = {
        soap_action: "#{@urn}##{action_name}",
          attributes: {
            'xmlns:u': @urn
          }
      }.merge(@call_options)

      unless @cookies.nil?
        attrs = attrs.merge(
          cookies: HTTPI::Cookie.new(@cookies)
        )
      end

      advanced_typecasting = @advanced_typecasting

      @client.call(action_name, attrs) do
        advanced_typecasting advanced_typecasting
        message(args)
      end
    end
  end
end
