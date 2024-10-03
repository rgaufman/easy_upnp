# frozen_string_literal: true

require 'webrick'

require 'easy_upnp/events/event_parsers'

module EasyUpnp
  class HttpListener
    class Options < EasyUpnp::OptionsBase
      DEFAULTS = {
        # Port to listen on. Default value "0" will cause OS to choose a random
        # ephemeral port
        listen_port: 0,

        # Address to bind listener on. Default value binds to all IPv4
        # interfaces.
        bind_address: '0.0.0.0',

        # By default, event callback just prints the changed state vars
        callback: lambda { |state_vars|
          puts state_vars.inspect
        },

        # Parses event bodies.  By default parse the XML into a hash.  Use
        # EasyUpnp::NoOpEventParser to skip parsing
        event_parser: EasyUpnp::DefaultEventParser
      }.freeze

      def initialize(options)
        super(options, DEFAULTS)
      end
    end

    def initialize(o = {}, &)
      @options = Options.new(o, &)
    end

    def listen
      unless @listen_thread
        @server = WEBrick::HTTPServer.new(
          Port: @options.listen_port,
          AccessLog: [],
          BindAddress: @options.bind_address
        )
        @server.mount('/', NotifyServlet, @options.callback, @options.event_parser.new)
      end

      @listen_thread ||= Thread.new do
        @server.start
      end

      url
    end

    def url
      raise 'Server not started' if !@listen_thread || !@server

      addr = Socket.ip_address_list.detect(&:ipv4_private?)
      port = @server.config[:Port]

      "http://#{addr.ip_address}:#{port}"
    end

    def shutdown
      raise 'Illegal state: server is not started' if @listen_thread.nil?

      @listen_thread.kill
      @listen_thread = nil
    end
  end

  class NotifyServlet < WEBrick::HTTPServlet::AbstractServlet
    def initialize(_server, block, parser)
      @callback = block
      @parser = parser
    end

    def do_NOTIFY(request, _response)
      @callback.call(@parser.parse(request.body))
    end
  end
end
