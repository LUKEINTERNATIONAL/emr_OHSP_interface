require_relative 'boot'

# Add logger before rails/all
require 'logger'
require 'rails/all'
require 'active_support'

Bundler.require(*Rails.groups)
require "emr_ohsp_interface"

module Dummy
  class Application < Rails::Application
    config.load_defaults 7.0
  end
end