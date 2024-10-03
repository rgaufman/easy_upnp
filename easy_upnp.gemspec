# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

require 'easy_upnp/version'

Gem::Specification.new do |gem|
  gem.name    = 'easy_upnp'
  gem.version = EasyUpnp::VERSION

  gem.summary = 'A super easy to use UPnP control point client'

  gem.authors  = ['Christopher Mullins']
  gem.email    = 'chris@sidoh.org'
  gem.homepage = 'http://github.com/sidoh/easy_upnp'

  gem.add_dependency 'nokogiri'
  gem.add_dependency 'nori'
  gem.add_dependency 'rake'
  gem.add_dependency 'rubyntlm'
  gem.add_dependency 'savon'
  gem.add_dependency 'webrick'

  ignores  = File.readlines('.gitignore').grep(/\S+/).map(&:chomp)
  dotfiles = %w[.gitignore]

  all_files_without_ignores = Dir['**/*'].reject do |f|
    File.directory?(f) || ignores.any? { |i| File.fnmatch(i, f) }
  end

  gem.files = (all_files_without_ignores + dotfiles).sort
  gem.executables = ['upnp-list']

  gem.require_path = 'lib'
  gem.metadata['rubygems_mfa_required'] = 'true'
end
