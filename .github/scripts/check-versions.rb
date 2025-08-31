#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

class VersionChecker
  RUBY_VERSIONS_URL = 'https://cache.ruby-lang.org/pub/ruby/index.txt'
  BUNDLER_API_URL = 'https://rubygems.org/api/v1/gems/bundler.json'

  def self.run
    checker = new
    updates = checker.check_for_updates
    
    if updates[:needed]
      puts "::set-output name=UPDATES_NEEDED::true"
      puts "::set-output name=UPDATE_MESSAGE::#{updates[:message].gsub("\n", '%0A')}"
      puts "::set-output name=LATEST_32::#{updates[:ruby]['3.2']}"
      puts "::set-output name=LATEST_33::#{updates[:ruby]['3.3']}"
      puts "::set-output name=LATEST_34::#{updates[:ruby]['3.4']}"
      puts "::set-output name=LATEST_BUNDLER::#{updates[:bundler][:latest]}"
    else
      puts "::set-output name=UPDATES_NEEDED::false"
    end
  end

  def check_for_updates
    current_versions = parse_current_versions
    latest_versions = fetch_latest_versions

    updates_needed = false
    update_messages = []

    # Check Ruby versions
    ['3.2', '3.3', '3.4'].each do |minor|
      current = current_versions[:ruby][minor]
      latest = latest_versions[:ruby][minor]
      
      if latest && current != latest
        updates_needed = true
        update_messages << "- Ruby #{minor}: #{current || 'not configured'} → #{latest}"
      end
    end

    # Check Bundler version
    if current_versions[:bundler] != latest_versions[:bundler]
      updates_needed = true
      update_messages << "- Bundler: #{current_versions[:bundler]} → #{latest_versions[:bundler]}"
    end

    {
      needed: updates_needed,
      message: update_messages.join("\n"),
      ruby: latest_versions[:ruby],
      bundler: {
        current: current_versions[:bundler],
        latest: latest_versions[:bundler]
      }
    }
  end

  private

  def parse_current_versions
    workflow_content = File.read('.github/workflows/build-and-publish.yml')
    dockerfile_content = File.read('Dockerfile')

    # Extract Ruby versions from workflow
    ruby_versions = {}
    if match = workflow_content.match(/\["([^"]+)",\s*"([^"]+)",\s*"([^"]+)"\]/)
      versions = [match[1], match[2], match[3]]
      versions.each do |version|
        minor = version.match(/^(\d+\.\d+)/)[1]
        ruby_versions[minor] = version
      end
    end

    # Extract Bundler version from Dockerfile
    bundler_version = dockerfile_content.match(/bundler:(\d+\.\d+\.\d+)/)[1]

    {
      ruby: ruby_versions,
      bundler: bundler_version
    }
  end

  def fetch_latest_versions
    ruby_versions = fetch_latest_ruby_versions
    bundler_version = fetch_latest_bundler_version

    {
      ruby: ruby_versions,
      bundler: bundler_version
    }
  end

  def fetch_latest_ruby_versions
    uri = URI(RUBY_VERSIONS_URL)
    response = Net::HTTP.get(uri)
    
    versions = {}
    lines = response.split("\n")
    
    # Parse all Ruby versions
    all_versions = lines.map do |line|
      if match = line.match(/ruby-(\d+\.\d+\.\d+)\.tar\.gz/)
        match[1]
      end
    end.compact

    # Find latest patch version for each minor version
    ['3.2', '3.3', '3.4'].each do |minor|
      matching = all_versions.select { |v| v.start_with?(minor + '.') }
      versions[minor] = matching.max_by { |v| Gem::Version.new(v) } if matching.any?
    end

    versions
  end

  def fetch_latest_bundler_version
    uri = URI(BUNDLER_API_URL)
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)
    data['version']
  rescue => e
    puts "Warning: Could not fetch Bundler version: #{e.message}"
    nil
  end
end

if __FILE__ == $0
  VersionChecker.run
end