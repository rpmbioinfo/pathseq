
params.input = "$projectDir/data/samplesheet.csv"
params.fasta = "$projectDir/data/ref/Homo_sapiens.GRCh38.dna_sm.primary_assembly.fa"
params.gtf = "$projectDir/data/ref/Homo_sapiens.GRCh38.109.gtf"
params.kraken = "$projectDir/data/kraken_db"

params.trim = true
params.adapter1 = "NONE"
params.adapter2 = "NONE"
samplesheet_ch = Channel.fromPath(params.input, checkIfExists: true)
params.outdir = "results"
params.multiqc_config = "$projectDir/multiqc_configs/general_multiqc.yaml"


params.levels = ["D","P","C","O","F","G","S"]

log.info """\
     P A T H S E Q    P I P E L I N E
    ===================================
    samplesheet     :    ${params.input}
    reference fasta :    ${params.fasta}
    reference_gtf   :    ${params.gtf}
    kraken_index    :    ${params.kraken}    
    outdir          :    ${params.outdir}
    trim            :    ${params.trim}
    levels          :    ${params.levels}
    """
    .stripIndent()


include { READ_SAMPLESHEET } from './subworkflows/read_samplesheet.nf'

include { TRIMGALORE } from './modules/trimgalore.nf'
include { FASTQC } from './modules/fastqc.nf'
include { MATE_LENGTH } from './modules/star_align.nf'
include { GENOME_GENERATE } from './modules/star_align.nf'
include { STAR_ALIGN } from './modules/star_align.nf'
include { KRAKEN_ALIGN } from './modules/kraken_align.nf'
include { BRACKEN_LEVEL } from './modules/bracken.nf'
include { BRACKEN_SUMMARIZE } from './modules/bracken.nf'
include { MULTIQC } from './modules/multiqc.nf'


workflow {
    READ_SAMPLESHEET(samplesheet_ch)
    .set {fastq_ch_raw}
    
    FASTQC(fastq_ch_raw.transpose())
    .set{ fastqc_ch }

    if (params.trim) {
      TRIMGALORE(fastq_ch_raw, params.adapter1, params.adapter2).set{ trim_ch }
      fastq_ch = trim_ch.reads
      trim_fastqc_ch = trim_ch.zip
      trim_multiqc_ch = trim_ch.trim_report
                                    
    } else {
       fastq_ch = fastq_ch_raw
    }
    MATE_LENGTH(fastq_ch.transpose().first())
    .set{ mate_len }
  
    GENOME_GENERATE(params.fasta, params.gtf, mate_len).set{ genome_index_ch }
    STAR_ALIGN(fastq_ch, params.fasta, params.gtf, genome_index_ch ).set { star_align_ch }

    KRAKEN_ALIGN(star_align_ch.mates, params.kraken).set{ kraken_ch }
    BRACKEN_LEVEL(kraken_ch.linked_report.combine(params.levels), params.kraken).set{ bracken_ch }
    BRACKEN_SUMMARIZE(bracken_ch.groupTuple()).set{ bracken_summary_ch }
    
    star_multiqc_ch = star_align_ch.starlog.collect()
    kraken_multiqc_ch = kraken_ch.report.collect()
    

    fastqc_ch.zip
            .mix(star_multiqc_ch)
            .mix(kraken_multiqc_ch)
            .set{multiqc_all}
    if ( params.trim ) {
        multiqc_all
        .mix(trim_fastqc_ch)
        .mix(trim_multiqc_ch)
        .set{multiqc_all}
    }

    MULTIQC(multiqc_all.collect(), params.multiqc_config)
    //fastqc_ch.mix(star_align_ch.starlog).mix(kraken_ch).view()
}

workflow.onComplete {
    log.info ( workflow.success ? "\nDone! Open the following report in your browser --> $params.outdir/multi_qc_report/multiqc_report.html\n" : "Oops .. something went wrong" )
}
