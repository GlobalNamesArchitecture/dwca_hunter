# frozen_string_literal: true

require "base64"
require "biodiversity"
require "dwc_archive"
require "dwca_hunter/resource"
require "fileutils"
require "htmlentities"
require "json"
require "logger"
require "net/http"
require "rest_client"
require "tmpdir"
require "uri"

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

    def normalize_authors(auth)
      reg = Regexp.new(/^([\(]?)(.*?)(([\s,\)][^[:upper:]]*)?$)/)
      auth = auth.gsub(/duPont/, 'du Pont')
      match = reg.match(auth)
      return auth if match.nil?
      a1, a2, a3 = match[1..3]
      a2mod = a2.gsub('&', ',')
      ary2 = a2mod.split(',').map(&:strip)
      a2 = move_initials(ary2) if ary2.size > 1
      "#{a1}#{a2}#{a3}"
    end

    def move_initials(ary)
      res = []
      ary.each do |a|
        if res.empty?
          res << a
          next
        end
        match = /^([[:upper:]]{1,4})(\sJr)?$/.match(a)
        if !match.nil?
          initialls = match[1].split('').join('. ')
          res[-1] = "#{initialls}. #{res[-1]}#{match[2].to_s}"
        else
          res << a
        end
      end
      res.size == 1 ? res[0] : "#{res[0..-2].join(', ')} & #{res[-1]}"
    end
  end
end

