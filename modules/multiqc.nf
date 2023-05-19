process MULTIQC {
    tag "Generating MultiQC report"
    container 'quay.io/biocontainers/multiqc:1.14--pyhdfd78af_0'

    memory '16 GB'
    cpus 4
  
    publishDir "$params.outdir", mode:'copy'


    input:
    path logs
    path multiqc_config

    output:
    path "multiqc_report/multiqc_report.html", emit: report
    path "multiqc_report/*_data"              , emit: data
    path "multiqc_report/*_plots"             , emit: plots

    script:
    """
    mkdir multiqc_report
    multiqc -f $logs -o multiqc_report -p -c $multiqc_config
    """
}


