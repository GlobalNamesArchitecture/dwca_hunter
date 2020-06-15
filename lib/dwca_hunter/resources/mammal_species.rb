# frozen_string_literal: true

module DwcaHunter
  # ResourceMammalSpecies converts "Mammal Species of the World" data
  # to DarwinCore Archive file
  class ResourceMammalSpecies < DwcaHunter::Resource
    def initialize(opts = {})
      @parser = Biodiversity::Parser
      @black_sp = black_species
      @command = "mammal-species"
      @title = "The Mammal Species of The World"
      @uuid = "464dafec-1037-432d-8449-c0b309e0a030"
      @data = []
      @extensions = []
      @count = 1
      @clades = { "Mammalia" => { rank: "class", id: @count } }
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
      DwcaHunter.logger_write(object_id, "Extracting data")
      encode
      collect_data
      generate_dwca
    end

    def download
      DwcaHunter.logger_write(object_id, "Downloading file -- "\
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
      DwcaHunter.logger_write(object_id, "Creating DarwinCore Archive file")
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
      name = rec[:commonname].tr("\u{0092}", "'")
      @extensions[0][:data] << [taxon_id, name, lang]
    end

    # rubocop:disable Metrics/AbcSize

    def process_synonyms(rec, taxon)
      accepted_id = taxon[0]
      parent_id = taxon[2]
      rank = taxon[-1]
      return unless %w[species subspecies].include? rank
      synonyms = rec[:synonyms].gsub(/\.$/, "").
                 gsub(%r{<[/ibsup]+>}, "").gsub(/[\s]+/, " ").split(";")
      synonyms = synonyms.map(&:strip)
      synonyms.map do |s|
        next if s =~ /<u>/
        s = rec[:genus] + " " + s if s =~ /^[a-z]/
        @count += 1
        id = @count
        if real_name?(s)
          @core << [id, nil, parent_id, accepted_id, s, "synonym", rank]
        else
          puts "Rejected: #{s}"
        end
      end
    end

    # rubocop:enable Metrics/AbcSize

    def real_name?(str)
      parsed = @parser.parse(str)
      return false unless parsed[:parsed]
      epithets = parsed[:canonicalName][:simple].split(" ")[1..-1]
      return false if epithets.nil? || epithets.empty?
      epithets.each do |e|
        return false if @black_sp[e]
      end
      true
    end

    def process_name(rec)
      name = [@core.last[4], rec[:author], rec[:date]]
      @core.last[4] = name.join(" ").gsub(%r{<[/ibsup]+>}, "").
                      gsub(/[\s]+/, " ").strip
      @core.last[1] = rec[:id]
    end

    # rubocop:disable Metrics/AbcSize

    def process_hierarchy(rec)
      parent_id = @clades["Mammalia"][:id]
      is_row_rank = false
      %i[order suborder infraorder superfamily family
         subfamily tribe genus subgenus species subspecies].each do |rank|
        is_row_rank = true if rank == rec[:taxonlevel].downcase.to_sym
        clade = rec[rank]
        clade = clade.capitalize if clade =~ /^[A-Z]+$/
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
            process_name(rec)
            return @core.last
          end
        end
        parent_id = clade_id
      end
    end
    # rubocop:enable Metrics/AbcSize

    def adjust_clade(rec, rank, clade)
      if %i[species subspecies].include? rank
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
            last_name: "Reader" }
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
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://globalnames.org/terms/localID",
                "http://rs.tdwg.org/dwc/terms/parentNameUsageID",
                "http://rs.tdwg.org/dwc/terms/acceptedNameUsageID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/taxonomicStatus",
                "http://rs.tdwg.org/dwc/terms/taxonRank"]]
      m = @clades["Mammalia"]
      @core << [m[:id], nil, nil, m[:id], "Mammalia", nil, "class"]
    end

    def black_species
      res = {}
      cnt = URI.parse(
        "https://www.dropbox.com/s/jl7sc7whuidsu8w/species-black.txt?dl=1"
      ) do |f|
        f.each_line do |l|
          res[l.strip] = 1
        end
      end
      res
    end

    def extensions_init
      @extensions << { data: [["http://rs.tdwg.org/dwc/terms/taxonID",
                               "http://rs.tdwg.org/dwc/terms/vernacularName",
                               "http://purl.org/dc/terms/language"]],
                       file_name: "vernacular_names.txt",
                       row_type: "http://rs.gbif.org/terms/1.0/VernacularName" }
    end
  end
end
