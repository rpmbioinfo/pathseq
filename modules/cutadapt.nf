process CUTADAPT {
    tag "Trimming on $reads"
    container 'quay.io/biocontainers/trim-galore:0.6.10--hdfd78af_0'

    cpus 4

    input:
    tuple val(meta), path(reads)
    val adapter1
    val adapter2

    output:
    tuple val(meta), path("*_1_trimmed*"), path("*_2_trimmed*")

    
    script:
    
    """
    if [ $adapter1 != "NONE"]
    then
        trim_galore \\
        --fastqc \\
        --length 20 \\
        -a $adapter1 \\
        -a2 $adapter2 \\
        --paired ${reads[0]} ${reads[1]}
    else
        trim_galore \\
        --fastqc \\
        --length 20 \\
        --paired ${reads[0]} ${reads[1]}
    fi
    """
}








