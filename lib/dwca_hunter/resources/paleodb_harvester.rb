class PaleodbHarvester
  def initialize(download_dir)
    @dir = File.join(download_dir, "json")
    FileUtils.mkdir_p(@dir)
    @in_dir = download_dir
    @taxa_csv = CSV.open(File.join(@in_dir, "taxa.csv"), headers: true)
    @refs_csv = CSV.open(File.join(@in_dir, "refs.csv"), headers: true)
    @taxa_refs_csv = CSV.open(File.join(@in_dir, "taxa_refs.csv"), headers: true)
    @occurences_csv = CSV.open(File.join(@in_dir, "occurences.csv"), headers: true)
  end

  def taxa
    # "orig_no","taxon_no","record_type","flags","taxon_rank",
    # "taxon_name","difference","accepted_no","accepted_rank",
    # "accepted_name","parent_no","reference_no","is_extant","n_occs"
    taxa = {}
    name2id = {}
    @taxa_csv.each do |r|
      r = strip(r)
      taxa[r["taxon_no"]] = { t_id: r["orig_no"], id: r["taxon_no"],
                              rank: r["taxon_rank"], name: r["taxon_name"],
                              auth: r["taxon_attr"],
                              extinct: extinct(r["is_extant"]),
                              vernacular: r["common_name"],
                              annot: r["difference"], acc_id: r["accepted_no"],
                              acc_rank: r["accepted_rank"],
                              acc_name: r["accepted_name"], ecol: ecol(r),
                              parent_id: r["parent_no"], ref: r["reference_no"],
                              occs_num: r["n_occs"], enterer: enterer(r) }

      name2id[r["taxon_name"]] = { id: r["taxon_no"], acc_id: r["accepted_no"] }
    end
    f = open(File.join(@dir, "taxa.json"), "w:utf-8")
    f.write(JSON.pretty_generate(taxa))
    f.close
    f = open(File.join(@dir, "name_id.json"), "w:utf-8")
    f.write(JSON.pretty_generate(name2id))
    f.close
  end

  def enterer(r)
    res = [r["enterer"], r["modifier"]].map(&:to_s)
      .map(&:strip).uniq.select { |e| e != "" }
    res.empty? ? "" : res.join(", ")
  end


  def extinct(val)
    val == "extinct" ? 1 : 0
  end

  def ecol(row)
    row = strip row
    "#{row['life_habit']} #{row['diet']}"
  end

  def refs
    # "reference_no","record_type","ref_type","author1init","author1last",
    # "author2init","author2last","otherauthors","pubyr","reftitle","pubtitle",
    # "editors","pubvol","pubno","firstpage","lastpage","publication_type",
    # "language","doi"

    # {"id":31671,"orig":true,"author":"Hahn, C. W.",
    #  "year":1834,"title":"Die wanzenartigen Insecten.",
    #  "details":"C. H. Zeh, Nurnberg.  2: 33--120.",
    #  "distribution":"Germany","comment":"n. sp."}
    refs = {}
    @refs_csv.each do |r|
      r = strip r
      authorship, author = authors(r)
      refs[r["reference_no"]] = { id: r["reference_no"], author: author,
                                  authorship: authorship,
                                  year: r["pubyr"],  title: r["reftitle"],
                                  details: details(r) }
    end
    f = open(File.join(@dir, "refs.json"), "w:utf-8")
    f.write(JSON.pretty_generate(refs))
    f.close
  end

  def authors(row)
    row = strip row
    au = ["#{row['author1init']} #{row['author1last']}".strip,
          "#{row['author2init']} #{row['author2last']}".strip,
          "#{row['otherauthors']}".strip]
    au = au.select { |a| !a.empty? }.map { |a| a.gsub(/[\s]{2,}/, " ").strip }
    [au[0..1].join(", "), au.join(", ")]
  end

  def details(row)
    row = strip row
    ref = "#{row['pubtitle']}"
    ref << " #{row['pubno']}" unless row['pubno'].empty?
    ref << ": #{row['firstpage']}" unless row['firstpage'].empty?
    ref << "--#{row['lastpage']}" unless row['lastpage'].empty?
    ref << " (#{row["doi"]})" unless row['doi'].empty?
    ref.gsub(/[\s]{2,}/, " ").strip
  end

  def taxa_refs
    tr = {}
    @taxa_refs_csv.each do |r|
      r = strip r
      row = { acc_id: r["accepted_no"], name: r["accepted_name"],
              ref_id: r["reference_no"] }
      if tr.key? r["accepted_no"]
        tr[r["accepted_no"]] << row
      else
        tr[r["accepted_no"]] = [row]
      end
    end
    f = open(File.join(@dir, "taxa_refs.json"), "w:utf-8")
    f.write(JSON.pretty_generate(tr))
    f.close
  end

  def occurences
    occ = {}
    @occurences_csv.each_with_index do |r, i|
      r = strip r
      row = { id: r["accepted_no"], name: r["accepted_name"], country: r["cc"],
              state: r["state"], age_min: r["min_ma"], age_max: r["max_ma"] }
      if occ.key? r["accepted_no"]
        occ[r["accepted_no"]] << row
      else
        occ[r["accepted_no"]] = [row]
      end
    end
    f = open(File.join(@dir, "occurences.json"), "w:utf-8")
    f.write(JSON.pretty_generate(occ))
    f.close
  end

  def strip(row)
    row.each_with_object({}) do |(k, v), h|
      h[k] = v.nil? ? nil : v.strip
    end
  end
end

