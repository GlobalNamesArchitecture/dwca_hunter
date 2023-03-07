# frozen_string_literal: true

module DwcaHunter
  class ResourceNCBI < DwcaHunter::Resource
    def initialize(opts = {})
      @command = "ncbi"
      @title = "National Center for Biotechnology Information"
      @url = "https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz"
      @uuid = "97d7633b-5f79-4307-a397-3c29402d9311"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "ncbi",
                                 "data.tar.gz")
      @names = {}
      @data = []
      @collected_names = ["genbank common name", "common name", "valid"]
      @core = []
      @extensions = []
      super
    end

    def unpack
      unpack_tar
    end

    def make_dwca
      set_vars
      get_names
      get_classification
      generate_dwca
    end

    private

    def set_vars
      @names_file = File.join(@download_dir, "names.dmp")
      @nodes_file = File.join(@download_dir, "nodes.dmp")
    end

    def get_names
      DwcaHunter.logger_write(object_id, "Collecting names...")
      open(@names_file).each_with_index do |line, i|
        DwcaHunter.logger_write(object_id, "Collected %s names..." % i) if i > 0 && i % BATCH_SIZE == 0
        line = line.split("|").map { |l| cleanup(l) }
        id = line[0]
        next if id == 1

        name = line[1]
        name_type = line[3]
        name_type = "valid" if name_type == "scientific name"
        begin
          name = name.gsub(/(^|\s)('|")(.*?)\2(\s|-|$)/, '\1\3\5').
                 gsub(/\s+/, " ")
        rescue NoMethodError
          puts "wrong name: %s" % name
          next
        end
        @names[id] = {} unless @names[id]
        if @names[id][name_type]
          (@names[id][name_type] << name)
        else
          (@names[id][name_type] = [name])
        end
      end
    end

    def get_classification
      DwcaHunter.logger_write(object_id, "Building classification...")
      open(@nodes_file, "r:utf-8").each_with_index do |line, i|
        DwcaHunter.logger_write(object_id, "Collected %s nodes..." % i) if i > 0 && i % BATCH_SIZE == 0
        line = line.split("|").map { |l| cleanup(l) }
        id = line[0]
        next if id == 1

        parent_tax_id = line[1]
        rank = line[2]
        hidden_flag = line[10]
        comments = line[12]

        rank = "" if rank == "no rank"
        parent_tax_id = nil if parent_tax_id == 1
        next unless @names[id] && @names[id]["valid"]

        vernacular_names = []
        synonyms = []
        @names[id].keys.each do |k|
          if @collected_names.include? k
            vernacular_names += @names[id][k] if k != "valid"
          else
            synonyms << { scientificName: @names[id][k],
                          taxonomicStatus: k }
          end
        end
        @data << {
          id: id,
          scientificName: @names[id]["valid"][0],
          parentNameUsageId: parent_tax_id,
          taxonRank: rank,
          taxonomicStatus: "valid",
          vernacularNames: vernacular_names,
          synonyms: []
        }
        @names[id].keys.each do |k|
        end
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id, "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonId",
                "http://purl.org/dc/terms/scientificName",
                "http://purl.org/dc/terms/parentNameUsageId",
                "http://purl.org/dc/terms/taxonRank"]]
      DwcaHunter.logger_write(object_id, "Assembling Core Data")
      count = 0
      @data.map do |d|
        count += 1
        if (count % BATCH_SIZE).zero?
          DwcaHunter.logger_write(object_id, "Traversing #{count} core " \
                                  "data record" % count)
        end
        @core << [d[:id],
                  d[:scientificName],
                  d[:parentNameUsageId],
                  d[:taxonRank]]
      end
      @extensions << {
        data: [["http://rs.tdwg.org/dwc/terms/TaxonID",
                "http://rs.tdwg.org/dwc/terms/vernacularName"]],
        file_name: "vernacular_names.txt"
      }
      @extensions << { data: [[
        "http://rs.tdwg.org/dwc/terms/taxonId",
        "http://rs.tdwg.org/dwc/terms/scientificName",
        "http://rs.tdwg.org/dwc/terms/taxonomicStatus"
      ]],
                       file_name: "synonyms.txt" }

      DwcaHunter.logger_write(object_id, "Creating verncaular name " \
                              "extension for DarwinCore Archive file")
      count = 0
      @data.each do |d|
        count += 1
        if (count % BATCH_SIZE).zero?
          DwcaHunter.logger_write(object_id,
                                  "Traversing #{count} extension data record")
        end
        d[:vernacularNames].each do |vn|
          @extensions[0][:data] << [d[:id], vn]
        end

        d[:synonyms].each do |synonym|
          @extensions[1][:data] << [d[:id],
                                    synonym[:scientificName],
                                    synonym[:taxonomicStatus]]
        end
      end
      @eml = {
        id: @uuid,
        title: @title,
        authors: [{ url: "http://www.ncbi.org" }],
        abstract: "The National Center for Biotechnology Information " \
                  "advances science and health by providing access to " \
                  "biomedical and genomic information.",
        metadata_providers: [
          { first_name: "mitry",
            last_name: "Mozzherin",
            email: "dmozzherin@mbl.edu" }
        ],
        url: @url
      }
      super
    end
  end
end
