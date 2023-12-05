nextflow.enable.dsl = 2

projectDir = "/scratch/rykalinav/rki_subtyping/Pipeline"
params.noenv = false
params.fullpipeline = false
params.iqtree = false
params.comet_rest = "${projectDir}/Scripts/comet_rest.py"
params.json_parser = "${projectDir}/Scripts/json_parser.py"
params.rega = "${projectDir}/Scripts/rega_cleanup.py"
params.g2p = "${projectDir}/Scripts/geno2pheno.py"
params.tag_parser = "${projectDir}/Scripts/tag_parser.py"
params.decision = "${projectDir}/Scripts/decision.py"
params.marking = "${projectDir}/Scripts/repeat_marking.py"
params.full_join = "${projectDir}/Scripts/full_join.py"
params.full_join_no_env = "${projectDir}/Scripts/full_join_no_env.py"
params.report = "${projectDir}/Scripts/report.py"
params.report_no_env = "${projectDir}/Scripts/report_no_env.py"
params.fasta_for_mafft = "${projectDir}/Scripts/fasta_for_mafft.py"
params.countplot = "${projectDir}/Scripts/plot.py"

params.outdir = null
if (!params.outdir) {
  println "outdir: $params.outdir"
  error "Missing output directory!"
}


log.info """
VERA RYKALINA - HIV-1 SUBTYPING PIPELINE
================================================================================
projectDir            : ${projectDir}
outdir                : ${params.outdir}
noenv                 : ${params.noenv}
mark_fasta            : ${params.marking}
comet                 : ${params.comet_rest}
json_to_csv           : ${params.json_parser}
clean_rega            : ${params.rega}
g2p                   : ${params.g2p}
get_tags              : ${params.tag_parser}
make_decision         : ${params.decision}
join_with_tags        : ${params.full_join}
join_with_tags_no_env : ${params.full_join_no_env}
fasta_for_mafft       : ${params.fasta_for_mafft}
report                : ${params.report}
report_no_env         : ${params.report_no_env}
countplot             : ${params.countplot}

September 2022
"""


process mark_fasta {
  publishDir "${params.outdir}/1_marked_fasta", mode: "copy", overwrite: true
  input:
 
    path fasta
    
  output:
    path "${fasta.getSimpleName()}M.fasta"
  
  script:
   """
    python3 ${params.marking} ${fasta} ${fasta.getSimpleName()}M.fasta

   """

}

process get_tags {
  publishDir "${params.outdir}/2_tags", mode: "copy", overwrite: true
  input:
    path xlsx
    
  output:
    path "tag_${xlsx.getSimpleName().split('_')[0]}_${xlsx.getSimpleName().split('_')[2]}_20M.csv"

  script:
   """
    python3 ${params.tag_parser} ${xlsx} tag_${xlsx.getSimpleName().split('_')[0]}_${xlsx.getSimpleName().split('_')[2]}_20M.csv
    
   """
}
process comet {
   publishDir "${params.outdir}/3_comet", mode: "copy", overwrite: true
  input:
    
    path fasta

  output:
    path "comet_${fasta.getSimpleName()}.csv"

  script:
  
  """
    python3 ${params.comet_rest} ${fasta} comet_${fasta.getSimpleName()}.csv
  """
  
}


process stanford {
  publishDir "${params.outdir}/4_json_files", mode: "copy", overwrite: true
  
  input:
    path fasta

  output:
    path "${fasta.getSimpleName()}.json"
  

  script:
    """
    sierrapy fasta ${fasta} --no-sharding -o ${fasta.getSimpleName()}.json
  
    """
}

process json_to_csv {
  publishDir "${params.outdir}/5_stanford", mode: "copy", overwrite: true
  input:
 
    path json
    
  output:
    path "stanford_${json.getSimpleName()}.csv"
  
  script:
   """
    python3 ${params.json_parser} ${json} stanford_${json.getSimpleName()}.csv
   """

}


process g2p {
  publishDir "${params.outdir}/6_g2p", mode: "copy", overwrite: true
  input:

    path csv
    
  output:
    path "g2p_${csv.getSimpleName().split('_g2p_')[1]}.csv"
  
  when:
    params.fullpipeline == true

  script:
   """
    python3 ${params.g2p} ${csv} g2p_${csv.getSimpleName().split('_g2p_')[1]}.csv
   """

}

process clean_rega {
  publishDir "${params.outdir}/7_rega", mode: "copy", overwrite: true
  input:

    path csv
    
  output:
    path "rega_${csv.getSimpleName().split('_Rega_')[1]}.csv"
  
  when:
    params.fullpipeline == true

  script:
   """
    python3 ${params.rega} ${csv} rega_${csv.getSimpleName().split('_Rega_')[1]}.csv
   """
}


process join_prrt {
  publishDir "${params.outdir}/8_joint_fragmentwise", mode: "copy", overwrite: true
  input:
 
    path stanford
    path comet
    path g2p
    path rega
    
  output:
    path "joint_${comet.getSimpleName().split('comet_')[1]}.csv"
  
   when:
    params.fullpipeline == true

  script:
    """
     mlr \
      --csv join \
      -u \
      --ul \
      --ur \
      -j SequenceName \
      -f ${stanford} ${comet} |\
      mlr --csv join -u --ul --ur -j SequenceName -f ${g2p} |\
      mlr --csv join -u --ul --ur -j SequenceName -f ${rega} > joint_${comet.getSimpleName().split('comet_')[1]}.csv
    """

}

process join_env {
  publishDir "${params.outdir}/8_joint_fragmentwise", mode: "copy", overwrite: true
  input:
 
    path comet
    path g2p
    path rega
    
  output:
    path "joint_${comet.getSimpleName().split('comet_')[1]}.csv"
  
  when:
   params.fullpipeline == true
  
  script:
    """
     mlr \
      --csv join \
      -u \
      --ul \
      --ur \
      -j SequenceName -f ${g2p} ${comet} |\
      mlr --csv join -u --ul --ur -j SequenceName -f ${rega} > joint_${comet.getSimpleName().split('comet_')[1]}.csv
    """

}

process join_int {
  publishDir "${params.outdir}/8_joint_fragmentwise", mode: "copy", overwrite: true
  input:
 
    path stanford
    path comet
    path g2p
    path rega
    
  output:
    path "joint_${comet.getSimpleName().split('comet_')[1]}.csv"
  
  when:
    params.fullpipeline == true

  script:
    """
     mlr \
      --csv join \
      -u \
      --ul \
      --ur \
      -j SequenceName \
      -f ${stanford} ${comet} |\
      mlr --csv join -u --ul --ur -j SequenceName -f ${g2p} |\
      mlr --csv join -u --ul --ur -j SequenceName -f ${rega} > joint_${comet.getSimpleName().split('comet_')[1]}.csv
    """

}


process make_decision {
  publishDir "${params.outdir}/9_with_decision", mode: "copy", overwrite: true
  input:

    path csv_prrt
    path csv_env
    path csv_int
    
  output:
    path "decision_${csv_prrt.getSimpleName().split('joint_')[1]}.csv"
    path "decision_${csv_env.getSimpleName().split('joint_')[1]}.csv"
    path "decision_${csv_int.getSimpleName().split('joint_')[1]}.csv"
  
  when:
    params.fullpipeline == true

  script:
   """
    python3 ${params.decision} ${csv_prrt} decision_${csv_prrt.getSimpleName().split('joint_')[1]}.csv
    python3 ${params.decision} ${csv_env} decision_${csv_env.getSimpleName().split('joint_')[1]}.csv
    python3 ${params.decision} ${csv_int} decision_${csv_int.getSimpleName().split('joint_')[1]}.csv
   """
}

process make_decision_no_env {
  publishDir "${params.outdir}/9_with_decision", mode: "copy", overwrite: true
  input:

    path csv_prrt
    path csv_int
    
  output:
    path "decision_${csv_prrt.getSimpleName().split('joint_')[1]}.csv"
    path "decision_${csv_int.getSimpleName().split('joint_')[1]}.csv"
  
  when:
    params.fullpipeline == true

  script:
   """
    python3 ${params.decision} ${csv_prrt} decision_${csv_prrt.getSimpleName().split('joint_')[1]}.csv
    python3 ${params.decision} ${csv_int} decision_${csv_int.getSimpleName().split('joint_')[1]}.csv
   """
}


process join_with_tags {
  publishDir "${params.outdir}/10_joint_with_tags", mode: "copy", overwrite: false
  input:
    path csv
    
  output:
    path "full_*.xlsx"
  
  when:
    params.fullpipeline == true

  script:
   """
    python3 ${params.full_join} ${csv} full_*.xlsx
   """
}

process join_with_tags_no_env {
  publishDir "${params.outdir}/10_joint_with_tags", mode: "copy", overwrite: false
  input:
    path csv
    
  output:
    path "full_*.xlsx"
  
  when:
    params.fullpipeline == true

  script:
   """
    python3 ${params.full_join_no_env} ${csv} full_*.xlsx
   """
}

process fasta_for_mafft {
  publishDir "${params.outdir}/11_fasta_for_mafft", mode: "copy", overwrite: true
  input:
    
    path xlsx
    
  output:
    
    path "*.fasta"

  when:
    params.fullpipeline == true

  script:
   """
    python3 ${params.fasta_for_mafft} ${xlsx} *.fasta
    """
}


  process prrt_concat_panel {
  publishDir "${params.outdir}/12_concat_with_panel", mode: "copy", overwrite: true
  input:
    path fragment
    path ref

  output:
    path "concat_${fragment.getSimpleName().split('mafft_')[1]}.fasta"
  when:
    params.fullpipeline == true

  script:
    """
    cat ${fragment} ${ref} > concat_${fragment.getSimpleName().split('mafft_')[1]}.fasta 
    """ 
    
  } 

  process int_concat_panel {
  publishDir "${params.outdir}/12_concat_with_panel", mode: "copy", overwrite: true
  input:
    path fragment
    path ref

  output:
      path "concat_${fragment.getSimpleName().split('mafft_')[1]}.fasta"
  when:
    params.fullpipeline == true

  script:
    """
    cat ${fragment} ${ref} > concat_${fragment.getSimpleName().split('mafft_')[1]}.fasta 
    """ 
    
  } 

  process env_concat_panel {
  publishDir "${params.outdir}/12_concat_with_panel", mode: "copy", overwrite: true
  input:
    path fragment
    path ref

  output:
    path "concat_${fragment.getSimpleName().split('mafft_')[1]}.fasta"
  when:
    params.fullpipeline == true

  script:
    """
    cat ${fragment} ${ref} > concat_${fragment.getSimpleName().split('mafft_')[1]}.fasta 
    """  
  } 

  process mafft {
  publishDir "${params.outdir}/13_mafft", mode: "copy", overwrite: false
  input:
      path fasta
  output:
      path  "msa_${fasta.getSimpleName().split('concat_')[1]}.fasta"

  when:
    params.fullpipeline == true

  script:
  
    """
    mafft --auto ${fasta} > msa_${fasta.getSimpleName().split('concat_')[1]}.fasta
    """
  }

process iqtree {
  label "iqtree"
  publishDir "${params.outdir}/14_iqtree", mode: "copy", overwrite: true
  input:
      path fasta
  output:
      path  "*.treefile"
      path  "*.iqtree"
      path  "*.log"

  when:
    params.iqtree == true

  script:
  
    """
    iqtree \
      -s ${fasta} \
      -m GTR+I+G4 \
      -B 10000 \
      -nm 10000 \
      -T 2 \
      --bnni \
      --seed 0 \
      --safe \
      --prefix iqtree_${fasta.getSimpleName().split('msa_')[1]}
    """
  }

process report {
  publishDir "${params.outdir}/15_report", mode: "copy", overwrite: false
  input:
    path xlsx
    
  output:
    path "*.xlsx"
  
  when:
    params.fullpipeline == true

  script:
   """
    python3 ${params.report} ${xlsx} *.xlsx
    """
}


process report_no_env {
  publishDir "${params.outdir}/15_report", mode: "copy", overwrite: false
  input:
    path xlsx
    
  output:
    path "*.xlsx"
  
  when:
    params.fullpipeline == true

  script:
   """
    python3 ${params.report_no_env} ${xlsx} *.xlsx
    """
}

process countplot {
  publishDir "${params.outdir}/15_report", mode: "copy", overwrite: true
  input:
    path xlsx
    
  output:
    path "*.png"
  
  when:
    params.fullpipeline == true

  script:
   """
    python3 ${params.countplot} ${xlsx} *.png
    """
}


workflow {
    inputfasta = channel.fromPath("${projectDir}/InputFasta/*.fasta")
    markedfasta = mark_fasta(inputfasta)
    inputtagxlsx = channel.fromPath("${projectDir}/AllSeqsCO20/*.xlsx")
    tag_csvChannel = get_tags(inputtagxlsx)
    cometChannel = comet(markedfasta)
    stanfordChannel = stanford(markedfasta.filter(~/.*_PRRT_20M.fasta$|.*_INT_20M.fasta$/))
    json_csvChannel = json_to_csv(stanfordChannel)
    inputg2pcsv = channel.fromPath("${projectDir}/ManualGeno2Pheno/*.csv")
    g2p_csvChannel = g2p(inputg2pcsv)
    inputregacsv = channel.fromPath("${projectDir}/ManualRega/*.csv")
    rega_csvChannel = clean_rega(inputregacsv)
    int_jointChannel = join_int(json_csvChannel.filter(~/.*_INT_20M.csv$/), cometChannel.filter(~/.*_INT_20M.csv$/), g2p_csvChannel.filter(~/.*_INT_20M.csv$/), rega_csvChannel.filter(~/.*_INT_20M.csv$/))
    prrt_jointChannel = join_prrt(json_csvChannel.filter(~/.*_PRRT_20M.csv$/), cometChannel.filter(~/.*_PRRT_20M.csv$/), g2p_csvChannel.filter(~/.*_PRRT_20M.csv$/), rega_csvChannel.filter(~/.*_PRRT_20M.csv$/))
   
    if (params.noenv) {
    decision_csvChannel = make_decision_no_env(prrt_jointChannel, int_jointChannel)
    all_dfs = tag_csvChannel.concat(decision_csvChannel).collect()
    fullChannel = join_with_tags_no_env(all_dfs)
    fasta_mafftChannel = fasta_for_mafft(fullChannel.flatten())
    fullFromPathChannel = channel.fromPath("${projectDir}/${params.outdir}/9_joint_with_tags/*.xlsx").collect()
    panelChannel = channel.fromPath("${projectDir}/References/*.fas")
    intConcatChannel = int_concat_panel(fasta_mafftChannel.filter(~/.*_INT_.*.fasta/), panelChannel.filter(~/.*_INT_.*.fas/))
    prrtConcatChannel = prrt_concat_panel(fasta_mafftChannel.filter(~/.*_PRRT_.*.fasta/), panelChannel.filter(~/.*_PRRT_.*.fas/))
    // MAFFT
    msaChannel = mafft(prrtConcatChannel.concat(intConcatChannel))
    // IQTREE (let iqtree get modified msa files)
    mafftPathChannel = channel.fromPath("${projectDir}/${params.outdir}/13_mafft/*.fasta")
    //iqtree(msaChannel)
    iqtree(mafftPathChannel)
    //REPORT
    reportChannel = report_no_env(fullFromPathChannel)
    // PLOT
    plotChannel = countplot(channel.fromPath("${projectDir}/${params.outdir}/15_report/*.xlsx"))
    } else {
  
    env_jointChannel = join_env(cometChannel.filter(~/.*_ENV_20M.csv$/), g2p_csvChannel.filter(~/.*_ENV_20M.csv$/), rega_csvChannel.filter(~/.*_ENV_20M.csv$/))
    decision_csvChannel = make_decision(prrt_jointChannel, env_jointChannel, int_jointChannel)
    all_dfs = tag_csvChannel.concat(decision_csvChannel).collect()
    fullChannel = join_with_tags(all_dfs)
    fasta_mafftChannel = fasta_for_mafft(fullChannel.flatten())
    fullFromPathChannel = channel.fromPath("${projectDir}/${params.outdir}/10_joint_with_tags/*.xlsx").collect()
    panelChannel = channel.fromPath("${projectDir}/References/*.fas")
    envConcatChannel = env_concat_panel(fasta_mafftChannel.filter(~/.*_ENV_.*.fasta/), panelChannel.filter(~/.*_ENV_.*.fas/))
    intConcatChannel = int_concat_panel(fasta_mafftChannel.filter(~/.*_INT_.*.fasta/), panelChannel.filter(~/.*_INT_.*.fas/))
    prrtConcatChannel = prrt_concat_panel(fasta_mafftChannel.filter(~/.*_PRRT_.*.fasta/), panelChannel.filter(~/.*_PRRT_.*.fas/))
    // MAFFT
    msaChannel = mafft(prrtConcatChannel.concat(intConcatChannel).concat(envConcatChannel))
    // IQTREE (let iqtree get modified msa files)
    mafftPathChannel = channel.fromPath("${projectDir}/${params.outdir}/13_mafft/*.fasta")
    iqtree(mafftPathChannel)
    //REPORT
    reportChannel = report(fullFromPathChannel)
    // PLOT
    plotChannel = countplot(channel.fromPath("${projectDir}/${params.outdir}/15_report/*.xlsx"))
    }
}
