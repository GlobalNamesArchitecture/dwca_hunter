# frozen_string_literal: true

module DwcaHunter
  class ResourceFungalNames < DwcaHunter::Resource
    def initialize(opts = { download: true, unpack: true })
      @command = "fungal-names"
      @title = "Fungal Names"
      # Download from https://nmdc.cn/fungalnames/released
      # LibreOffice, save csv file, upload it to box.com
      @url = "https://uofi.box.com/shared/static/g5lmbwj799wnh5vug6kqijttxt91x9dm.txt"
      @UUID = "b0ac4f6f-fc56-41b4-ad69-6af30a881e7e"
      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "fungal-names",
                                 "data.tsv")
      @synonyms = []
      @names = []
      @vernaculars = []
      @extensions = []
      @synonyms_hash = {}
      @vernaculars_hash = {}
      super(opts)
    end

    def download
      `curl -s -L #{@url} -o #{@download_path}`
    end

    def unpack; end

    def make_dwca
      DwcaHunter.logger_write(object_id, "Extracting data")
      get_names
      generate_dwca
    end

    private

    def get_names
      Dir.chdir(@download_dir)
      collect_names
    end

    def classification(str)
      kingdom = phylum = klass = order = family = genus = ""
      return [kingdom, phylum, klass, order, family, genus] if str.nil?

      el = str.split("|").map(&:strip)
      el.each do |e|
        el2 = e.split("_")
        next if el2.size != 2

        case el2[0]
        when "k" then kingdom = el2[1]
        when "p" then phylum = el2[1]
        when "c" then klass = el2[1]
        when "o" then order = el2[1]
        when "f" then family = el2[1]
        when "g" then genus = el2[1]
        end
      end
      [kingdom, phylum, klass, order, family, genus]
    end

    def collect_names
      @names_index = {}
      file = CSV.open(File.join(@download_dir, "data.tsv"),
                      headers: true, col_sep: "\t", quote_char: "щ")
      file.each_with_index do |row, i|
        taxon_id = row["Registration identifier"]
        next if taxon_id.nil?

        taxon_id = taxon_id.strip
        accepted_taxon_id = row["Current name registration identifier"]
        accepted_taxon_id = accepted_taxon_id.nil? ? taxon_id : accepted_taxon_id.strip
        name_string = row["Fungal name"].strip
        authors = row["Authors"]
        year = row["Year of publication"]
        rank = row["Rank"].strip.downcase
        status = row["Name status"]
        status = status.nil? ? "" : status.strip.downcase
        status = "synonym" if status == "synonymy"
        kingdom, phylum, klass, order, family, genus = classification(row["Classification"])
        code = "ICN"

        @names << { taxon_id: taxon_id,
                    accepted_taxon_id: accepted_taxon_id,
                    name_string: "#{name_string} #{authors}".strip,
                    rank: rank,
                    status: status,
                    year: year,
                    kingdom: kingdom,
                    phylum: phylum,
                    class: klass,
                    order: order,
                    family: family,
                    genus: genus,
                    code: code }
        puts "Processed %s names" % i if i % 10_000 == 0
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id,
                              "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://rs.tdwg.org/dwc/terms/acceptedNameUsageID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/taxonRank",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalStatus",
                "http://rs.tdwg.org/dwc/terms/namePublishedInYear",
                "http://rs.tdwg.org/dwc/terms/kingdom",
                "http://rs.tdwg.org/dwc/terms/phylum",
                "http://rs.tdwg.org/dwc/terms/class",
                "http://rs.tdwg.org/dwc/terms/order",
                "http://rs.tdwg.org/dwc/terms/family",
                "http://rs.tdwg.org/dwc/terms/genus",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:accepted_taxon_id], n[:name_string],
                  n[:rank], n[:status], n[:year], n[:kingdom], n[:phylum],
                  n[:class], n[:order], n[:family], n[:genus], n[:code]]
      end

      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { first_name: "Fang",
            last_name: "Wang" },
          { first_name: "Ke",
            last_name: "Wang" },
          { first_name: "Lei",
            last_name: "Cai" },
          { first_name: "Mingjun",
            last_name: "Zhao" },
          { first_name: "Paul",
            last_name: "Kirk" },
          { first_name: "Guomei",
            last_name: "Fan" },
          { first_name: "Qinglan",
            last_name: "Sun" },
          { first_name: "Bo",
            last_name: "Li" },
          { first_name: "Shuai",
            last_name: "Wang" },
          { first_name: "Zhengfei",
            last_name: "Yu" },
          { first_name: "Dong",
            last_name: "Han" },
          { first_name: "Juncai",
            last_name: "Ma" },
          { first_name: "Linhuan",
            last_name: "Wu" },
          { first_name: "Yijian",
            last_name: "Yao" }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "Fungal Names, a global data repository of fungal " \
        "taxonomy, is established by the Institute of Microbiology, " \
        "Chinese Academy of Sciences. The repository aims at providing " \
        "integrated services on Fungi and fungus-like organisms " \
        "involving fungal name registration, species identification, " \
        "specimen preservation, taxonomists overview and related " \
        "information query, statistics or data sharing for people " \
        "worked with or interested in mycology.\n\n" \
        "Fang Wang, Ke Wang, Lei Cai, Mingjun Zhao, Paul M Kirk, " \
        "Guomei Fan, Qinglan Sun, Bo Li, Shuai Wang, Zhengfei Yu, " \
        "Dong Han, Juncai Ma, Linhuan Wu*, Yijian Yao*, " \
        "Fungal names: a comprehensive nomenclatural repository " \
        "and knowledge base for fungal taxonomy, Nucleic Acids " \
        "Research, 2022, gkac926, https://doi.org/10.1093/nar/gkac926",
        url: "https://nmdc.cn/fungalnames"
      }
      super
    end
  end
end
