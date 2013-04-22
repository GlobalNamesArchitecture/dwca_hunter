# encoding: utf-8
class DwcaHunter
  class Downloader

    attr_reader :url

    def initialize(source_url, file_path)
      @source_url = source_url
      @file_path = file_path
      @url = Url.new(source_url)
      @download_length = 0
      @filename = nil
    end

    # downloads a given file into a specified filename. 
    # If block is given returns download progress
    def download
      raise "#{@source_url} is not accessible" unless @url.valid?
      f = open(@file_path,'wb')
      count = 0
      @url.net_http.request_get(@url.path) do |r|
        r.read_body do |s|
          @download_length += s.length
          f.write s
          if block_given?
            count += 1
            if count % 100 == 0
              yield @download_length
            end
          end
        end
      end
      f.close
      downloaded = @download_length
      @download_length = 0
      downloaded
    end

    def download_with_percentage
      start_time = Time.now
      download do |r|
        percentage = r.to_f/@url.header.content_length * 100
        elapsed_time = Time.now - start_time
        eta = calculate_eta(percentage, elapsed_time)
        res = { percentage: percentage, 
                elapsed_time: elapsed_time, 
                eta: eta }
        yield res
      end
    end

    protected

    def calculate_eta(percentage, elapsed_time)
      eta = elapsed_time/percentage * 100 - elapsed_time
      eta = 1.0 if eta <= 0
      eta
    end
  end
end
