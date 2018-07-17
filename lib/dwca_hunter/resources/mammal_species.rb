module DwcaHunter
  class ResourceMammalSpecies < DwcaHunter::Resource
    def initialize(opts = {})
      @command = "mammal-species"
      @title = "The Mammal Species of The World"
      @uuid = "464dafec-1037-432d-8449-c0b309e0a030"
      @data = []
      @extensions = []
      @count = 1
      @clades = {"Mammalia" => { rank: "class", id: @count}}
      @url = "http://www.departments.bucknell.edu"\
             "/biology/resources/msw3/export.asp"
      @download_path = File.join(Dir.tmpdir, "dwca_hunter",
                                 "mammalsp", "msw3-all.csv")
      super
    end

    def needs_unpack?
      false
    end

    def make_dwca
      DwcaHunter::logger_write(self.object_id, "Extracting data")
      encode
      collect_data
      generate_dwca
    end

    def download
      DwcaHunter::logger_write(self.object_id, "Downloading file -- "\
                               "it will take some time...")
      dlr = DwcaHunter::Downloader.new(url, @download_path)
      dlr.download
    end

    private

    def encode
      DwcaHunter::Encoding.latin1_to_utf8(@download_path)
    end

    def collect_data
      opts = { headers: true, header_converters: :symbol }
      CSV.open(@download_path + ".utf_8", opts).each do |row|
        @data << row.to_hash
      end
    end

    def generate_dwca
      DwcaHunter::logger_write(self.object_id,
                               'Creating DarwinCore Archive file')
      core_init
      extensions_init
      eml_init
      @data.each do |rec|
        taxon = process_hierarchy(rec)
        process_vernaculars(rec, taxon)
        process_synonyms(rec, taxon)
      end
      super
    end

    def process_vernaculars(rec, taxon)
      return if rec[:commonname].to_s == ""
      taxon_id = taxon[0]
      lang = "en"
      name = rec[:commonname].gsub("\u{0092}", "'")
      @extensions[0][:data] << [taxon_id, name, lang]

    end

    def process_synonyms(rec, taxon)
      accepted_id = taxon[0]
      parent_id = taxon[2]
      rank = taxon[-1]
      return unless ['species', 'subspecies'].include? rank
      synonyms = rec[:synonyms].gsub(/\.$/, "").
        gsub(/<[\/ib]+>/, "").gsub(/[\s]+/, " ").split(";")
      synonyms = synonyms.map(&:strip)
      synonyms = synonyms.map do |s|
        next if s.match(/<u>/)
        if s.match(/^[a-z]/)
          s = rec[:genus] + " " + s
        end
        @count += 1
        id = @count
        @core << [id, nil, parent_id, accepted_id, s, "synonym", rank]
      end
    end

    def process_name(rec, rank)
      name =[@core.last[4], rec[:author], rec[:date]]
      @core.last[4] = name.join(" ").gsub(/[\s]+/, " ").strip
      @core.last[1] = rec[:id]
    end

    def process_hierarchy(rec)
      parent_id = @clades["Mammalia"][:id]
      is_row_rank = false
      [:order, :suborder, :infraorder, :superfamily, :family,
       :subfamily, :tribe, :genus, :subgenus,
       :species, :subspecies].each do |rank|
       is_row_rank = true if rank == rec[:taxonlevel].downcase.to_sym
        clade = rec[rank]
        clade = clade.capitalize if clade.match(/^[A-Z]+$/)
        next if clade.to_s == ""
        clade_id = nil
        clade = adjust_clade(rec, rank, clade)
        if @clades.key?(clade)
          clade_id = @clades[clade][:id]
        else
          @count += 1
          clade_id = @count
          @clades[clade] = { id: clade_id, rank: rank }
          @core << [clade_id, nil, parent_id, clade_id, clade, nil, rank.to_s]
          if is_row_rank
            process_name(rec, rank)
            return @core.last
          end
        end
        parent_id = clade_id
      end
    end

    def adjust_clade(rec, rank, clade)
      if [:species, :subspecies].include? rank
        clade = [rec[:genus], rec[:species]]
        clade << rec[:subspecies] if rank == :subspecies
        clade.join(" ").gsub(/[\s]+/, " ").strip
      else
        clade
      end
    end

    def eml_init
      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { first_name: "Don",
            last_name: "Wilson" },
          { first_name: "DeeAnn",
            last_name: "Reader" },
      ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
      ],
        abstract: "Mammal Species of the World, 3rd edition (MSW3) is "\
        "a database of mammalian taxonomy, based upon the 2005 book "\
        "Mammal Species of the World. A Taxonomic and Geographic Reference "\
        "(3rd ed). Don E. Wilson & DeeAnn M. Reeder (editors).",
        url: "http://www.vertebrates.si.edu/msw/mswcfapp/msw/index.cfm"
      }
    end

    def core_init
      @core = [['http://rs.tdwg.org/dwc/terms/taxonID',
                'http://globalnames.org/terms/localID',
                'http://rs.tdwg.org/dwc/terms/parentNameUsageID',
                'http://rs.tdwg.org/dwc/terms/acceptedNameUsageID',
                'http://rs.tdwg.org/dwc/terms/scientificName',
                'http://rs.tdwg.org/dwc/terms/taxonomicStatus',
                'http://rs.tdwg.org/dwc/terms/taxonRank']]
      m = @clades["Mammalia"]
      @core << [m[:id], nil, nil, m[:id], "Mammalia", nil, "class"]
    end

    def extensions_init
      @extensions << { data: [['http://rs.tdwg.org/dwc/terms/taxonID',
                               'http://rs.tdwg.org/dwc/terms/vernacularName',
                               'http://purl.org/dc/terms/language']],
                       file_name: 'vernacular_names.txt',
                       row_type: 'http://rs.gbif.org/terms/1.0/VernacularName'
                     }
    end
  end
end
