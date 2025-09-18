process GATK4_NVSCOREVARIANTS {
    tag "$meta.id"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gatk4:4.6.2.0--py310hdfd78af_0':
        'biocontainers/gatk4:4.6.2.0--py310hdfd78af_0' }"

    input:
    tuple val(meta), path(vcf), path(tbi), path(aligned_input)
    path fasta
    path fai

    output:
    tuple val(meta), path("*cnn.vcf.gz")    , emit: vcf
    tuple val(meta), path("*cnn.vcf.gz.tbi"), emit: tbi
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    // In NVSCOREVARIANTS there is the same problem as with CNNSCOREVARIANTS because of some python packages
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "GATK4_NVSCOREVARIANTS module does not support Conda. Please use Docker / Singularity / Podman instead."
    }
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def aligned_input = aligned_input ? "--input $aligned_input" : ""

    def avail_mem = 3072
    if (!task.memory) {
        log.info '[GATK NVScoreVariants] Available memory not known - defaulting to 3GB. Specify process memory requirements to change this.'
    } else {
        avail_mem = (task.memory.mega*0.8).intValue()
    }
    """
    export THEANO_FLAGS="base_compiledir=\$PWD"

    gatk --java-options "-Xmx${avail_mem}M -XX:-UsePerfData" \\
        NVScoreVariants \\
        --variant $vcf \\
        --output ${prefix}.cnn.vcf.gz \\
        --reference $fasta \\
        $aligned_input \\
        --tmp-dir . \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gatk4: \$(echo \$(gatk --version 2>&1) | sed 's/^.*(GATK) v//; s/ .*\$//')
    END_VERSIONS
    """
}
