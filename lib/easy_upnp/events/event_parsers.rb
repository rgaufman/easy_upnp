# frozen_string_literal: true

require 'nokogiri'

module EasyUpnp
  class DefaultEventParser
    def parse(event_xml)
      x = Nokogiri::XML(event_xml)
      prop_changes = x.xpath('//e:propertyset/e:property/*', e: 'urn:schemas-upnp-org:event-1-0').map do |n|
        [n.name.to_sym, n.text]
      end

      prop_changes.to_h
    end
  end

  class NoOpEventParser
    def parse(event_xml)
      event_xml
    end
  end
end
