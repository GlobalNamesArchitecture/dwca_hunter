# encoding: utf-8
class DwcaHunter
  class ResourceFreebase < DwcaHunter::Resource
    def initialize(opts = {})
      @title = "Freebase"
      @uuid = "bacd21f0-44e0-43e2-914c-70929916f257"
      @download_path = File.join(DEFAULT_TMP_DIR, "dwca_hunter", "freebase", "data.json")
      @data = []
      super
    end

    def needs_unpack?
      false
    end

    def make_dwca
    end

    def download
      DwcaHunter::logger_write(self.object_id, "Querying freebase for species information...")
      q = {
        query: [{
          type:"/biology/organism_classification",
          id: nil,
          guid: nil,
          name: nil,
          scientific_name: nil,
          synonym_scientific_name: [],
          higher_classification: { 
            id: nil,
            guid: nil,
            scientific_name: nil,
            optional: true,
          },
      }],
          cursor: true,
      }
      count = 0
      requests_num = 0
      while true
        res = JSON.load RestClient.get("http://api.freebase.com/api/service/mqlread?query=%s" % URI.encode(q.to_json))
        requests_num += 1
        break if res["result"] == nil || res["result"].empty?
        DwcaHunter::logger_write(self.object_id, "Received %s names" % count) if requests_num % 10 == 0
        count += res["result"].size
        @data << res["result"]
        q[:cursor] = res["cursor"]
      end

      data = JSON.pretty_generate @data
      f = open(@download_path, "w:utf-8")
      f.write(data)
      f.close
    end

  end
end
