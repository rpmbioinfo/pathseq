process KRAKEN_ALIGN {
    tag "Aligning non-host reads from $meta to Kraken2"
    container 'quay.io/biocontainers/kraken2:2.1.2--pl5321h7d875b9_1'
    
    memory '96 GB'
    cpus 30
    
    publishDir "$params.outdir/kraken_report", mode:'copy', pattern: "*.kreport"
    publishDir "$params.outdir/kraken", mode:'copy', pattern: "*.kraken"

    input:
    tuple val(meta), path(mate1), path(mate2)
    path kraken_db


    output:
    tuple val(meta), path("*.kreport"), emit: linked_report
    path "*.kreport", emit: report
    path "*.kraken", emit: kraken

    script:
    """
    kraken2 --threads $task.cpus \\
            --db ${kraken_db}/ \\
            --report ${meta}.kreport \\
            --paired $mate1 $mate2 > ${meta}.kraken 
    """
}
