# frozen_string_literal: true

require "logger"
require "fileutils"
require "uri"
require "tmpdir"
require "net/http"
require "json"
require "dwc_archive"
require "dwca_hunter/resource"
require "rest_client"
require "base64"

Dir[File.join(__dir__, "dwca_hunter", "*.rb")].
  each { |f| require f }

Dir[File.join(__dir__, "dwca_hunter", "resources", "*.rb")].
  each { |f| require f }

# DwcaHunter a namespace module for the project.
module DwcaHunter
  BATCH_SIZE = 10_000

  class << self
    attr_reader :resource

    def logger
      @logger ||= Logger.new(nil)
    end

    attr_writer :logger

    def logger_reset
      self.logger = Logger.new(nil)
    end

    def logger_write(obj_id, message, method = :info)
      logger.send(method, "|#{obj_id}|#{message}|")
    end

    def process(resource)
      resource.download if resource.needs_download?
      resource.unpack if resource.needs_unpack?
      resource.make_dwca
    end

    def resources
      ObjectSpace.each_object(Class).select do |c|
        c < Resource
      end
    end
  end
end
