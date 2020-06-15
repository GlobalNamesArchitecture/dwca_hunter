# frozen_string_literal: true

module DwcaHunter
  class ResourcePaleoBioDb < DwcaHunter::Resource
    OCCURANCE_URL = "http://paleobiodb.org/data1.2/occs/list.txt?" \
                    "datainfo&rowcount&base_name=Life&taxon_reso=species&" \
                    "idqual=certain&show=ecospace,loc,paleoloc,acconly"
    TAXA_URL = "http://paleobiodb.org/data1.2/taxa/list.txt?datainfo&" \
              "rowcount&base_name=Life&variant=all&" \
              "show=attr,common,app,parent,ecospace,ref,refattr,entname"
    REFS_URL = "http://paleobiodb.org/data1.2/taxa/refs.txt?datainfo&" \
               "rowcount&base_name=Life&select=taxonomy"
    TAXA_REFS_URL = "http://paleobiodb.org/data1.2/taxa/byref.txt?datainfo&" \
                    "rowcount&base_name=Life&select=taxonomy"

    URLS = {
      occurences: OCCURANCE_URL,
      taxa: TAXA_URL,
      refs: REFS_URL,
      taxa_refs: TAXA_REFS_URL
    }.freeze

    def initialize(opts = {})
      # opts = {download: false}
      @command = "paleodb"
      @title = "The Paleobiology Database"
      @UUID =  "fad9970e-c358-4e1b-8cc3-f9ad2582751f"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "paleobiodb", "fake.csv")
      @synonyms = []
      @names = []
      @vernaculars = []
      @extensions = []
      @synonyms_hash = {}
      @vernaculars_hash = {}
      super(opts)
    end

    def download
      puts "Downloading from original."
      URLS.each do |k, v|
        file_name = k.to_s + ".txt"
        f = File.open(File.join(@download_dir, file_name), "w:utf-8")
        puts "Getting #{k}"
        data = RestClient::Request.execute(method: :get, url: v, timeout: 600)
        f.write(data)
        f.close
      end
      remove_header_text
    end

    def unpack; end

    def make_dwca
      DwcaHunter.logger_write(object_id, "Extracting data")
      harvester = PaleodbHarvester.new(@download_dir)
      harvester.taxa
      harvester.refs
      harvester.taxa_refs
      harvester.occurences
      @taxa_json = JSON.parse(File.read(
                                File.join(@download_dir, "json", "taxa.json")
                              ), symbolize_names: true)
      @name_id_json = JSON.parse(File.read(
                                   File.join(@download_dir, "json", "name_id.json")
                                 ), symbolize_names: true)
      get_names
      generate_dwca
    end

    private

    def remove_header_text
      URLS.each do |k, _v|
        file_name = k.to_s + ".csv"
        fout = File.open(File.join(@download_dir, file_name),
                         "w:utf-8")
        csv_started = false
        File.open(File.join(@download_dir, k.to_s + ".txt")).each do |l|
          unless csv_started
            csv_started = true if l =~ /"Records:"/
            next
          end
          fout.write(l)
        end
      end
    end

    def get_names
      sp, syn = species
      sp.each_with_index do |r, i|
        puts format("Processing %s species", i) if (i % 5000).zero?
        append_accepted_species(r)
      end
      syn.each_with_index do |r, i|
        puts format("Processing %s synonyms", i) if (i % 5000).zero?
        append_synonyms(r)
      end
    end

    def append_accepted_species(row)
      c = classification({}, row)
      name = {
        id: row[:id],
        acc_id: row[:id],
        klass: c[:class],
        order: c[:order],
        family: c[:family],
        genus: c[:genus],
        name: row[:name],
        auth: row[:auth]
      }
      @names << name
    end

    def append_synonyms(row)
      id, acc_id = synonymId(row)
      syn = {
        id: id,
        name: row[:name],
        auth: row[:auth],
        acc_id: acc_id
      }
      @names << syn
    end

    def synonymId(row)
      acc_id = row[:acc_id]
      id = row[:id]
      acc_id = @name_id_json[row[:acc_name].to_sym][:id] if id == acc_id
      [id, acc_id]
    rescue StandardError
      puts "Unable to get synonymId"
    end

    def classification(data, row)
      data = {}
      stack = [[data, row]]
      until stack.empty?
        data, row = stack.delete_at(0)
        next unless @taxa_json[row[:parent_id].to_sym] && row[:parent_id] != row[:id]

        row = @taxa_json[row[:parent_id].to_sym]
        data[row[:rank].to_sym] = row[:name] unless data[row[:rank].to_sym]
        stack << [data, row]
      end
      data
    end

    def species
      @taxa_json.values.select { |v| (v[:rank] == "species") }.
        partition do |v|
        (v[:name] == v[:acc_name]) || v[:acc_id].nil?
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id,
                              "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/acceptedNameUsageID",
                "http://rs.tdwg.org/dwc/terms/class",
                "http://rs.tdwg.org/dwc/terms/order",
                "http://rs.tdwg.org/dwc/terms/family",
                "http://rs.tdwg.org/dwc/terms/genus",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        name_string = "#{n[:name]} #{n[:auth]}".strip
        @core << [n[:id], name_string, n[:acc_id],
                  n[:kingdom], n[:phylum], n[:klass], n[:order], n[:family],
                  n[:genus], n[:code]]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { email: "admin@paleobiodb.org" }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "The Paleobiology Database (PBDB) is a non-governmental, non-profit public resource for paleontological data. It has been organized and operated by a multi-disciplinary, multi-institutional, international group of paleobiological researchers. Its purpose is to provide global, collection-based occurrence and taxonomic data for organisms of all geological ages, as well data services to allow easy access to data for independent development of analytical tools, visualization software, and applications of all types. The Database’s broader goal is to encourage and enable data-driven collaborative efforts that address large-scale paleobiological questions.",
        url: @url
      }
      super
    end
  end
end
