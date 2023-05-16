workflow READ_SAMPLESHEET {
    take: 
    samplesheet_ch

    main:
        samplesheet_ch
        .splitCsv(header:true, sep:',')
        .map { create_fastq_channel( it ) }
        .set { reads}

    emit:
    reads

}

def create_fastq_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id           = row.sample

    def fastq_meta = []

    
    fastq_meta = [ meta.id, [ file(row.fastq_1), file(row.fastq_2) ] ]
    
    return fastq_meta
}