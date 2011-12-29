require 'logger'
require 'fileutils'
require 'uri'
require 'net/http'
require 'json'
require 'dwc-archive'
require 'dwca-hunter/resource'
require 'iconv'
require 'rest_client'
Dir[File.join(File.dirname(__FILE__), "dwca-hunter", "*.rb")].each {|f| require f}

class DwcaHunter

  VERSION = open(File.join(File.dirname(__FILE__), '..', 'VERSION')).readline.strip
  DEFAULT_TMP_DIR = "/tmp"
  BATCH_SIZE = 10_000

  def self.logger
    @@logger ||= Logger.new(nil)
  end

  def self.logger=(logger)
    @@logger = logger
  end

  def self.logger_reset
    self.logger = Logger.new(nil)
  end

  def self.logger_write(obj_id, message, method = :info)
    self.logger.send(method, "|%s|%s|" % [obj_id, message])
  end
  def initialize(resource)
    @resource = resource
  end

  def process
    @resource.download if @resource.needs_download?
    @resource.unpack if @resource.needs_unpack?
    @resource.make_dwca
  end

end
