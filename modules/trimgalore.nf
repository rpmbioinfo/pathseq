process TRIMGALORE {
    tag "Trimming on $reads"
    container 'quay.io/biocontainers/trim-galore:0.6.10--hdfd78af_0'

    cpus 4

    input:
    tuple val(meta), path(reads)
    val adapter1
    val adapter2

    output:
    tuple val(meta), path("trimmed/*val_*.fq.gz"), emit: reads
    path "trimmed/*_fastqc.zip" , emit: zip
    path "*trimmed/*trimming_report.txt", emit: trim_report
    
    script:
    
    """
    mkdir trimmed
    if [ $adapter1 != "NONE"]
    then
        trim_galore \\
        --fastqc \\
        -o trimmed \\
        --length 20 \\
        -a $adapter1 \\
        -a2 $adapter2 \\
        --paired ${reads[0]} ${reads[1]}
    else
        trim_galore \\
        -o trimmed \\
        --fastqc \\
        --length 20 \\
        --paired ${reads[0]} ${reads[1]}
    fi
    """
}








