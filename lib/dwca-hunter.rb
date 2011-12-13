require 'logger'
require 'fileutils'
require 'uri'
require 'net/http'
require 'json'
require 'dwc-archive'
require 'dwca-hunter/resource'
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
    download if @resource.needs_download?
    @resource.unpack if @resource.needs_unpack?
    @resource.make_dwca
  end

private
  def download
    DwcaHunter::logger_write(self.object_id, "Starting download of '%s'" % @resource.url)
    url = @resource.url
    percentage = 0
    if url.match(/^\s*http:\/\//)
      dlr = DwcaHunter::Downloader.new(url, @resource.download_path)
      downloaded_length = dlr.download_with_percentage do |r|
        if r[:percentage].to_i != percentage
          percentage = r[:percentage].to_i
          msg = sprintf("Downloaded %.0f%% in %.0f seconds ETA is %.0f seconds", percentage, r[:elapsed_time], r[:eta])
          DwcaHunter::logger_write(self.object_id, msg)
        end
      end
      DwcaHunter::logger_write(self.object_id, "Download finished, Size: %s" % downloaded_length)
    else
      `curl -s #{url} > #{download_path}`
    end
  end
end
