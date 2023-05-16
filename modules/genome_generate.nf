

process GENOME_GENERATE {
    tag "FASTQC on $sample_id"
    container 'quay.io/biocontainers/mulled-v2-1fa26d1ce03c295fe2fdcf85831a92fbcbd7e8c2:59cdd445419f14abac76b31dd0d71217994cbcc9-0'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("fastqc_${meta}_logs/*.html"), emit: html
    tuple val(meta), path("fastqc_${meta}_logs/*.zip") , emit: zip

    

    script:
    """
    mkdir fastqc_${meta}_logs
    fastqc -o fastqc_${meta}_logs -f fastq -q ${reads}
    """
}