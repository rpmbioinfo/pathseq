
workflow FASTQC_RAW {
    take:
    fastq_ch_raw

    process RENAME {

}

    main:
        fastq_ch_raw
        .transpose()
        
        .set { reads}

    emit:
    reads

}

