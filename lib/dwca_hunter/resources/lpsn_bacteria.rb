# frozen_string_literal: true

module DwcaHunter
  class ResourceLPSN < DwcaHunter::Resource
    def initialize(opts = { download: true, unpack: true })
      @command = "lpsn-bact"
      @title = "List of Prokaryotic names with Standing in Nomenclature"
      @url = "https://uofi.box.com/shared/static/86ufg8wovbc029weuid9h5akjuc85zch.csv"
      @UUID = "3d10ba04-be3a-4617-b9d5-07f1ae5ac195"

      @download_path = File.join(Dir.tmpdir,
                                 "dwca_hunter",
                                 "lpsn_bact",
                                 "data.csv")
      @synonyms = []
      @names = []
      @vernaculars = []
      @extensions = []
      @synonyms_hash = {}
      @vernaculars_hash = {}
      super(opts)
    end

    def download
      puts "Downloading LPSN file."
      # -L allows redirections
      `curl -L -s #{@url} -o #{@download_path}`
    end

    def unpack; end

    def make_dwca
      DwcaHunter.logger_write(object_id, "Extracting data")
      get_names
      generate_dwca
    end

    private

    def get_names
      puts "Processing names"
      file = CSV.open(@download_path, headers: true)

      file.each_with_index do |row, i|
        genus = row["genus_name"]
        sp = row["sp_epithet"]
        ssp = row["subsp_epithet"]

        auth = row["authors"]
        auth = auth.gsub(/\(Approved.*/, '')
        auth = auth.gsub(/emend\..*/, '')

        name = [genus, sp, ssp, auth].join(" ").gsub(/\s+/, " ")

        rank = "genus"
        rank = "species" if sp.to_s.strip != ""
        rank = "subspecies" if ssp.to_s.strip != ""

        taxon_id = row["record_no"]
        accepted_id = row["record_lnk"]
        accepted_id = taxon_id if accepted_id.to_s == ""

        statuses = row["status"].split(";").map(&:strip)
        status = ""
        status = statuses[-1] if statuses.size > 1

        guid = row["address"]

        res = { taxon_id: taxon_id,
                accepted_id: accepted_id,
                guid: guid,
                name_string: name,
                rank: rank,
                status: status,
                code: "ICNP" }
        @names << res
        puts "Processed #{i} names" if (i % 5_000).zero?
      end
    end

    def generate_dwca
      DwcaHunter.logger_write(object_id,
                              "Creating DarwinCore Archive file")
      @core = [["http://rs.tdwg.org/dwc/terms/taxonID",
                "http://rs.tdwg.org/dwc/terms/acceptedNameUsageID",
                "http://globalnames.org/terms/localID",
                "http://rs.tdwg.org/dwc/terms/scientificName",
                "http://rs.tdwg.org/dwc/terms/taxonomicStatus",
                "http://rs.tdwg.org/dwc/terms/rank",
                "http://rs.tdwg.org/dwc/terms/nomenclaturalCode"]]
      @names.each do |n|
        @core << [n[:taxon_id], n[:accepted_id], n[:guid], n[:name_string],
                  n[:status], n[:rank], n[:code]]
      end
      @eml = {
        id: @uuid,
        title: @title,
        authors: [
          { first_name: "Jean",
            middle_name: "P.",
            last_name: "Euzéby" }
        ],
        metadata_providers: [
          { first_name: "Dmitry",
            last_name: "Mozzherin",
            email: "dmozzherin@gmail.com" }
        ],
        abstract: "The List of Prokaryotic names with Standing in " \
          "Nomenclature (LPSN) provides comprehensive information on the " \
          "nomenclature of prokaryotes and much more." \
          "LPSN is a free to use service founded by Jean P. Euzéby in 1997 " \
          "and later on maintained by Aidan C. Parte.",
        url: "https://lpsn.dsmz.de/"
      }
      super
    end
  end
end
