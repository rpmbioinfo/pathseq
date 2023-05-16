



process FASTQC {
    tag "FASTQC on $meta"
    container 'quay.io/biocontainers/fastqc:0.11.9--0'

    cpus 4
    memory 32.GB
    
    input:
    tuple val(meta), path(reads)

    output:
    path "fastqc_${meta}_raw_logs/*.html", emit: html
    path "fastqc_${meta}_raw_logs/*.zip" , emit: zip

    

    script:
    def newName = "raw_${reads[0].baseName}.fq.gz"
    """
    mkdir fastqc_${meta}_raw_logs
    mv ${reads} ${newName}
    fastqc -o fastqc_${meta}_raw_logs -f fastq -q $newName -t ${task.cpus}
    """
}
