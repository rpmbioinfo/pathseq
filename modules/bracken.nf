
process BRACKEN_LEVEL {
    tag "Compute abundances for ${level} for ${meta}"
    container 'nanozoo/bracken:2.8--dcb3e47'

    publishDir "$params.outdir/bracken/individual_reports", mode:'copy', pattern: "*.bracken"
    
    memory 30.GB
    cpus 4


    input:
    tuple val(meta), path(kraken_report), val(level)
    path kraken_db


    output:
    tuple val(level),path("*.bracken")

    script:
    """
    mkdir bracken_output
    bracken -d ${kraken_db} \\
            -l ${level} \\
            -i ${kraken_report} \\
            -o ${meta}.bracken \\
            -w bracken_output/${meta}_bracken_${level}.kreport
    """
}


process BRACKEN_SUMMARIZE {
    tag "Summarise abundances across files for {level}"
    container 'nanozoo/bracken:2.8--dcb3e47'

    publishDir "$params.outdir/bracken", mode:'copy', pattern: "combined_bracken_*.txt"
    
    memory 30.GB
    cpus 4


    input:
    tuple val(level), path(bracken_files)

    output:
    path "combined_bracken_*.txt"

    script:
    """
    combine_bracken_outputs.py \\
        --files ${bracken_files} \\
        -o combined_bracken_${level}.txt 

    """

}
