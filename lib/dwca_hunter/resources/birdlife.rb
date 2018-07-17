module DwcaHunter
  class ResourceBirdLife < DwcaHunter::Resource
    def initialize(opts = {})
      @command = "bird-life"
      @title = "BirdLife International"
      @uuid = "b1d8de7a-ab96-455f-acd8-f3fff2d7d169"
      @data = []
      @extensions = []
      @url = "http://www.birdlife.org/datazone/userfiles"\
             "/file/Species/Taxonomy/BirdLife_Checklist_Version_70.zip"
      @download_path = File.join(Dir.tmpdir, "dwca_hunter", "birdlife",
                                 "fake.zip")
      @clades = {}
      super
    end

    def needs_unpack?
      false
    end

    def download
    end

    def make_dwca
      organize_data
      generate_dwca
    end

    private

    def generate_dwca
      DwcaHunter::logger_write(self.object_id,
                               'Creating DarwinCore Archive file')
      core_init
      extensions_init
      eml_init
      @data.each do |rec|
        process(rec)
      end
      super
    end

    def core_init
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://globalnames.org/terms/localID",
                "http://rs.tdwg.org/dwc/terms/parentNameUsageID",
                "http://rs.tdwg.org/dwc/terms/acceptedNameUsageID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/taxonomicStatus",
                "http://rs.tdwg.org/dwc/terms/taxonRank"]]
      @count = 1
      @core << [@count, nil, nil, @count, "Aves", nil, "class"]
    end

    def process(rec)
      parent_id = 1
      [:order, :family].each do |rank|
        clade_id = nil
        unless @clades[rec[rank]]
          @count += 1
          @clades[rec[rank]] = { id: @count }
        end
        clade_id = @clades[rec[rank]][:id]
        @core << [clade_id, nil, parent_id, clade_id, rec[rank], nil, rank.to_s]
        parent_id = clade_id
      end
      @count += 1
      @core << [@count, rec[:local_id], parent_id, @count,
                rec[:scientific_name], nil, rec[:rank]]
      taxon = @core.last
      process_synonyms(rec, taxon)
      process_vernaculars(rec, taxon)
    end

    def process_synonyms(rec, taxon)
      rec[:synonyms].each do |syn|
        @count += 1
        @core << [@count, nil, taxon[2], taxon[0], syn, "synonym", taxon[-1]]
      end
    end

    def process_vernaculars(rec, taxon)
      rec[:vernaculars].each do |v|
        taxon_id = taxon[0]
        lang = "en"
        name = v
        @extensions[0][:data] << [taxon_id, name, lang]
      end
    end

    def extensions_init
      @extensions << { data: [["http://rs.tdwg.org/dwc/terms/taxonID",
                               "http://rs.tdwg.org/dwc/terms/vernacularName",
                               "http://purl.org/dc/terms/language"]],
                       file_name: "vernacular_names.txt",
                       row_type: "http://rs.gbif.org/terms/1.0/VernacularName"
                     }
    end

    def organize_data
      DwcaHunter::logger_write(self.object_id,
                               "Organizing data")
      path = File.join(__dir__, "..",
                       "..", "files", "birdlife_7.csv")
      opts = { headers: true, header_converters: :symbol }
      collect_data(path, opts)
    end

    def collect_data(path, opts)
      @data = CSV.open(path, opts).each_with_object([]) do |row, data|
        order = row[:order]
        order = order.capitalize if order.match(/^[A-Z]+$/)
        family = row[:familyname]
        scientific_name = [row[:scientificname], row[:authority]].join(" ").
          strip.gsub(/[\s]+/, " ")
        rank = row[:taxonomictreatment] == "R" ? "species" : "not recognized"
        local_id = row[:sisrecid]
        vernaculars = collect_vernaculars(row)
        synonyms = collect_synonyms(row)
        data << { order: order, family: family, rank: rank,
                  scientific_name: scientific_name, synonyms: synonyms,
                  local_id: local_id, vernaculars: vernaculars }
      end
    end

    def collect_synonyms(row)
      synonyms = row[:synonyms]
      synonyms ? synonyms.split(";").map(&:strip) : []
    end

    def collect_vernaculars(row)
      name1 = row[:commonname]
      names = name1 ? [name1] : []
      other = row[:alternativecommonnames]
      if other
        names += other.split(";").map(&:strip)
      end
      names
    end

    def eml_init
      @eml = {
        id: @uuid,
        title: @title,
        authors: [],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
      ],
        abstract: "BirdLife is widely recognised as the world leader in bird "\
                  "conservation. Rigorous science informed by practical "\
                  "feedback from projects on the ground in important sites "\
                  "and habitats enables us to implement successful "\
                  "conservation programmes for birds and all nature.",
        url: "http://www.birdlife.org/"
      }
    end
  end
end
