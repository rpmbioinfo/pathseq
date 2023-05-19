

process MATE_LENGTH {
    tag "Finding mate length..."
    container 'ubuntu:latest'

    input:
    tuple val(meta), path(reads)

    output:
    env mateLength

    script:
    """
    mkdir mate_length
    mateLength=\$(zcat ${reads} | head -n 4000 | awk 'NR%2==0 {print length(\$1)}' | sort -rn | head -n 1 )
    """

}

process GENOME_GENERATE {
    tag "Generating index"
    container 'quay.io/biocontainers/star:2.7.10b--h9ee0642_0'

    cpus 4 
    memory '50 GB'
    
    input:
    path fasta
    path gtf
    val mateLen

    output:
    path 'star'

    script:
    def memory = task.memory ? "--limitGenomeGenerateRAM ${task.memory.toBytes() - 100000000}" : ''
    """
    mateLength=\$(($mateLen - 1 ))
    mkdir star

    STAR \\
    --runMode genomeGenerate \\
    --genomeDir star/ \\
    --genomeFastaFiles ${fasta} \\
    --genomeSAsparseD 2 \\
    --runThreadN ${task.cpus} \\
    --sjdbGTFfile ${gtf} \\
    --sjdbOverhang \${mateLength} \\
    $memory
    """
}


process STAR_ALIGN {
    tag "Aligning $meta"
    container 'quay.io/biocontainers/star:2.7.10b--h9ee0642_0'
    
    cpus 4
    memory '50 GB'

    publishDir "$params.outdir/star_logs", mode:'copy', pattern: "*.final.out"

    input:
    tuple val(meta), path(reads)
    path fasta
    path gtf
    path index

    output:
    tuple val(meta), path("${meta}_starUnmapped.out.mate1"), path("${meta}_starUnmapped.out.mate2"), emit: mates
    path '*.final.out', emit: starlog    

    script:
    """

    STAR --genomeDir $index \\
         --genomeLoad LoadAndRemove \\
         --readFilesIn ${reads} \\
         --readFilesCommand zcat \\
         --outSAMunmapped Within \\
         --runThreadN ${task.cpus} \\
         --outSAMtype BAM Unsorted \\
         --outFileNamePrefix ${meta}_star \\
         --outReadsUnmapped Fastx 
    
    """
}

