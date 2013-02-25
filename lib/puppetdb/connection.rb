require 'puppetdb'

class PuppetDB::Connection
  require 'rubygems'
  require 'puppet'
  require 'puppetdb/parser'
  require 'puppet/network/http_pool'
  require 'uri'
  require 'json'

  def initialize(host='puppetdb', port=443, use_ssl=true)
    Puppet.initialize_settings
    @host = host
    @port = port
    @use_ssl = use_ssl
    @parser = PuppetDB::Parser.new
  end

  # Parse a query string into a PuppetDB query
  def parse_query(query, endpoint=:hosts)
    @parser.scan_str(query).optimize.evaluate endpoint
  end

  # Get the listed facts for all hosts matching query
  # return it as a hash of hashes
  def facts(facts, hostquery)
    q = ['and', ['in', 'certname', ['extract', 'certname', ['select-facts', hostquery]]], ['or', *facts.collect { |f| ['=', 'name', f]}]]
    facts = {}
    query(:facts, q).each do |fact|
      if facts.include? fact['certname'] then
        facts[fact['certname']][fact['name']] = fact['value']
      else
        facts[fact['certname']] = {fact['name'] => fact['value']}
      end
    end
    facts
  end

  # Execute a PuppetDB query
  def query(endpoint, query=nil)
    http = Puppet::Network::HttpPool.http_instance(@host, @port, @use_ssl)
    headers = { "Accept" => "application/json" }

    if query == [] or query == nil
      resp, data = http.get("/v2/#{endpoint.to_s}", headers)
      raise Puppet::Error, "PuppetDB query error: [#{resp.code}] #{resp.msg}" unless resp.kind_of?(Net::HTTPSuccess)
      return PSON.parse(data)
    else
      params = URI.escape("?query=#{query.to_json}")
      resp, data = http.get("/v2/#{endpoint.to_s}#{params}", headers)
      raise Puppet::Error, "PuppetDB query error: [#{resp.code}] #{resp.msg}, query: #{query.to_json}" unless resp.kind_of?(Net::HTTPSuccess)
      return PSON.parse(data)
    end
  end
end
