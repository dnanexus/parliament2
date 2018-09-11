illumina_bam=$1
illumina_bai=$2
ref_fasta=$3
prefix=$4
filter_short_contigs=$5
run_breakdancer=$6
run_breakseq=$7
run_manta=$8
run_cnvnator=$9
run_lumpy=${10}
run_delly_deletion=${11}
run_delly_insertion=${12}
run_delly_inversion=${13}
run_delly_duplication=${14}
run_genotype_candidates=${15}
run_atlas=${16}
run_stats=${17}
run_svviz=${18}
svviz_only_validated_candidates=${19}
dnanexus=${20}

# Files to include:
# - GATK jar file
# - CreateSequence Dictionary jar file
# - Regions BED file
# - Target BED file
# - Covmask file
# - MAF sites file
# - DBSNP file
# - DBSNP TBI
# - Known indels file
# - Known indels TBI
# - Mills indels
# - Mills TBI

if [[ ! -f "${illumina_bam}" ]] || [[ ! -f "${ref_fasta}" ]]; then
    if [[ "$dnanexus" == "True" ]]; then
        dx-jobutil-report-error "ERROR: An invalid (nonexistent) input file has been specified."
    else
        echo "ERROR: An invalid (nonexistent) input file has been specified."
        exit 1
    fi
fi

cp "${ref_fasta}" ref.fa

if [[ "$run_breakdancer" != "True" ]] && [[ "$run_breakseq" != "True" ]] && [[ "$run_manta" != "True" ]] && [[ "$run_cnvnator" != "True" ]] && [[ "$run_lumpy" != "True" ]] && [[ "$run_delly_deletion" != "True" ]] && [[ "$run_delly_insertion" != "True" ]] && [[ "$run_delly_inversion" != "True" ]] && [[ "$run_delly_duplication" != "True" ]]; then
    echo "WARNING: Did not detect any SV modules requested by the user through command-line flags."
    echo "Running with default SV modules: Breakdancer, Breakseq, Manta, CNVnator, Lumpy, and Delly Deletion"
    run_breakdancer="True"
    run_breakseq="True"
    run_manta="True"
    run_cnvnator="True"
    run_lumpy="True"
    run_delly_deletion="True"
fi

# update-alternatives --set java /usr/lib/jvm/java-7-openjdk-amd64/jre/bin/java
# java -jar GenomeAnalysisTK.jar -version || (update-alternatives --set java /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java && java -jar GenomeAnalysisTK.jar -version)

samtools faidx ref.fa &
ref_genome=$(python /home/dnanexus/get_reference.py)
lumpy_exclude_string=""
if [[ "$ref_genome" == "b37" ]]; then
    lumpy_exclude_string="-x b37.bed"
elif [[ "$ref_genome" == "hg19" ]]; then
    lumpy_exclude_string="-x hg19.bed"
else
    lumpy_exclude_string="-x hg38.bed"
fi

lumpy_scripts="/home/dnanexus/lumpy-sv/scripts"

# If no callers have been selected by tag, run the default set and print a message out

if [[ "$run_breakdancer" != "True" && "$run_breakseq" != "True" && "$run_manta" != "True" && "$run_cnvnator" != "True" &&  "$run_delly" != "True" && "$run_delly_deletion" != "True" && "$run_delly_insertion" != "True" && "$run_delly_inversion" != "True" && "$run_delly_duplication" != "True" ]]; then
        echo "User did not provide list of callers to use. Applying default selection instead (Breakdancer, Breakseq, CNVnator, Lumpy, Manta, and Delly (Deletion Only)"
        run_breakdancer="True"
        run_breakseq="True"
        run_manta="True"
        run_cnvnator="True"
        run_lumpy="True"
        run_delly_deletion="True"
fi

# Get extension and threads
extn=${illumina_bam##*.}
threads="$(nproc)"
threads=$((threads - 3))

echo "Set up and index BAM/CRAM"

# # Allow for CRAM files
if [[ "$extn" == "cram" ]] || [[ "$extn" == "CRAM" ]]; then
    echo "CRAM file input"
    mkfifo tmp_input.bam
    samtools view "${illumina_bam}" -bh -@ "$threads" -T ref.fa -o - | tee tmp_input.bam > input.bam & 
    samtools index tmp_input.bam
    wait
    cp tmp_input.bam.bai input.bam.bai
    rm tmp_input.bam
elif [[ "$illumina_bai" == "None" ]]; then
    echo "BAM file input, no index exists"
    cp "${illumina_bam}" input.bam
    samtools index input.bam
else
    echo "BAM file input, index exists"
    cp "${illumina_bam}" input.bam
    cp "${illumina_bai}" input.bam.bai
fi

wait

echo "Generate contigs"

samtools view -H input.bam | python /getContigs.py "$filter_short_contigs" > contigs

mkdir -p /home/dnanexus/out/log_files/

# This is new
# Frontloading xAtlas
if [[ "$run_atlas" == "True" ]]; then
    /xatlas -h
    /xatlas --ref ref.fa --in input.bam --prefix "${prefix}" -s "${prefix}" --gvcf 1> /home/dnanexus/out/log_files/atlas.stdout 2> /home/dnanexus/out/log_files/atlas.stderr &
fi

# This is new
# if [[ "$run_stats" == "True" ]]; then
#     python /split_maf.py $maf_name chr1 chr2 chr3 chr4 chr5 chr6 chr7 chr8 > maf.0.vcf
#     python /split_maf.py $maf_name chr9 chr10 chr11 chr12 chr13 chr15 chr15 > maf.1.vcf
#     python /split_maf.py $maf_name chr16 chr17 chr18 chr19 chr20 chr21 chr22 chrX chrY > maf.2.vcf
#     verifyBamID --vcf maf.0.vcf --bam input.bam --out ${prefix}.chr1-8 $vbid_opt $vbid_user_opts 1> /home/dnanexus/out/log_files/verify.0.stout.log 2> /home/dnanexus/out/log_files/verify.0.stderr.log &
#     verifyBamID --vcf maf.1.vcf --bam input.bam --out ${prefix}.chr9-15 $vbid_opt $vbid_user_opts 1> /home/dnanexus/out/log_files/verify.1.stout.log 2> /home/dnanexus/out/log_files/verify.1.stderr.log &
#     verifyBamID --vcf maf.2.vcf --bam input.bam --out ${prefix}.chr16-Y $vbid_opt $vbid_user_opts 1> /home/dnanexus/out/log_files/verify.2.stout.log 2> /home/dnanexus/out/log_files/verify.2.stderr.log &
#     #verifyBamID --vcf $maf_name --bam input.bam --out ${prefix} $vbid_opt $vbid_user_opts 1>verify.0.stout.log 2>verify.0.stderr.log &
# fi

# This is new
as_opt="-r $regions_name -t $target_name -m $cov_name"
vbid_opt="--ignoreRG"
as_opt2=""


# Execute Stats app
if [[ "$run_stats" == "True" ]]; then
    echo "Running alignstats"
    alignstats -v -p -i input.bam -o "${prefix}".AlignStatsReport.txt $as_opt $as_opt2 $as_user_opts 1> /home/dnanexus/out/log_files/alignstats.stdout.log 2> /home/dnanexus/out/log_files/alignstats.stderr.log &
    samtools flagstat input.bam > /home/dnanexus/out/"${prefix}".flagstats &
fi
# End new things

if [[ "$run_breakseq" == "True" || "$run_manta" == "True" ]]; then
    echo "Launching jobs that cannot be parallelized by contig"
fi

# JOBS THAT CANNOT BE PARALLELIZED BY CONTIG
# BREAKSEQ2
if [[ "$run_breakseq" == "True" ]]; then
    echo "BreakSeq"
    bplib="/breakseq2_bplib_20150129/breakseq2_bplib_20150129.gff"
    work="breakseq2"
    timeout 6h ./breakseq2-2.2/scripts/run_breakseq2.py --reference ref.fa \
        --bams input.bam --work "$work" \
        --bwa /usr/local/bin/bwa --samtools /usr/local/bin/samtools \
        --bplib_gff "$bplib" \
        --nthreads "$(nproc)" --bplib_gff "$bplib" \
        --sample "$prefix" 1> /home/dnanexus/out/log_files/breakseq.stdout.log 2> /home/dnanexus/out/log_files/breakseq.stderr.log &
fi

# MANTA
if [[ "$run_manta" == "True" ]]; then
    echo "Manta"
    timeout 6h runManta 1> /home/dnanexus/out/log_files/manta.stdout.log 2> /home/dnanexus/out/log_files/manta.stderr.log &
fi

# PREPARE FOR BREAKDANCER
if [[ "$run_breakdancer" == "True" ]]; then
    timeout 2h /breakdancer/cpp/bam2cfg -o breakdancer.cfg input.bam
fi

concat_breakdancer_cmd=
concat_cnvnator_cmd=

count=0
delly_deletion_concat=""
delly_inversion_concat=""
delly_duplication_concat=""
delly_insertion_concat=""
lumpy_merge_command=""

if [[ $(nproc) -eq 36 ]]; then
    thread_limit=48
elif [[ $(nproc) -eq 32 ]]; then
    thread_limit=44
elif [[ $(nproc) -eq 16 ]]; then
    thread_limit=22
else
    thread_limit=$(nproc)
fi

if [[ "$run_delly_deletion" == "True" ]] || [[ "$run_delly_insertion" == "True" ]] || [[ "$run_delly_inversion" == "True" ]] || [[ "$run_delly_duplication" == "True" ]]; then
   run_delly="True"
fi

# Process management for launching jobs
if [[ "$run_cnvnator" == "True" ]] || [[ "$run_delly" == "True" ]] || [[ "$run_breakdancer" == "True" ]] || [[ "$run_lumpy" == "True" ]]; then
    echo "Launching jobs parallelized by contig"
    while read contig; do
        if [[ $(samtools view input.bam "$contig" | head -n 20 | wc -l) -ge 10 ]]; then
            count=$((count + 1))
            if [[ "$run_breakdancer" == "True" ]]; then
                echo "Running Breakdancer for contig $contig"
                timeout 4h /breakdancer/cpp/breakdancer-max breakdancer.cfg input.bam -o "$contig" > breakdancer-"$count".ctx &
                concat_breakdancer_cmd="$concat_breakdancer_cmd breakdancer-$count.ctx"
            fi

            if [[ "$run_cnvnator" == "True" ]]; then
                echo "Running CNVnator for contig $contig"
                runCNVnator "$contig" "$count" &
                concat_cnvnator_cmd="$concat_cnvnator_cmd output.cnvnator_calls-$count"
            fi

            echo "Running sambamba view"
            timeout 2h sambamba view -h -f bam -t $(nproc) input.bam $contig > chr.$count.bam
            echo "Running sambamba index"
            sambamba index -t $(nproc) chr.$count.bam 

            if [[ "$run_delly_deletion" == "True" ]]; then  
                echo "Running Delly (deletions) for contig $contig"
                timeout 6h delly -t DEL -o $count.delly.deletion.vcf -g ref.fa chr.$count.bam & 
                delly_deletion_concat="$delly_deletion_concat $count.delly.deletion.vcf"
            fi

            if [[ "$run_delly_inversion" == "True" ]]; then 
                echo "Running Delly (inversions) for contig $contig"
                timeout 6h delly -t INV -o $count.delly.inversion.vcf -g ref.fa chr.$count.bam &
                delly_inversion_concat="$delly_inversion_concat $count.delly.inversion.vcf"
            fi

            if [[ "$run_delly_duplication" == "True" ]]; then 
                echo "Running Delly (duplications) for contig $contig"
                timeout 6h delly -t DUP -o $count.delly.duplication.vcf -g ref.fa chr.$count.bam &
                delly_duplication_concat="$delly_duplication_concat $count.delly.duplication.vcf"
            fi

            if [[ "$run_delly_insertion" == "True" ]]; then 
                echo "Running Delly (insertions) for contig $contig"
                timeout 6h delly -t INS -o $count.delly.insertion.vcf -g ref.fa chr.$count.bam &
                delly_insertion_concat="$delly_insertion_concat $count.delly.insertion.vcf"
            fi
            
            if [[ "$run_lumpy" == "True" ]]; then
                echo "Running Lumpy for contig $contig"
                timeout 6h ./lumpy-sv/bin/lumpyexpress -B chr.$count.bam -o lumpy.$count.vcf $lumpy_exclude_string -k &
                lumpy_merge_command="$lumpy_merge_command lumpy.$count.vcf"
            fi

            breakdancer_threads=$(top -n 1 -b -d 10 | grep -c breakdancer)
            cnvnator_threads=$(top -n 1 -b -d 10 | grep -c cnvnator)
            sambamba_processes=$(top -n 1 -b -d 10 | grep -c sambamba)
            manta_processes=$(top -n 1 -b -d 10 | grep -c manta)
            breakseq_processes=$(top -n 1 -b -d 10 | grep -c breakseq)
            delly_processes=$(top -n 1 -b -d 10 | grep -c delly)
            lumpy_processes=$(top -n 1 -b -d 10 | grep -c lumpy)
            active_threads=$(python /getThreads.py "$breakdancer_threads" "$cnvnator_threads" "$sambamba_processes" "$manta_processes" "$breakseq_processes" "$delly_processes" "$lumpy_processes")
            
            while [[ $active_threads -ge $(nproc) ]]; do
                echo "Waiting for 60 seconds"
                breakdancer_threads=$(top -n 1 -b -d 10 | grep -c breakdancer)
                cnvnator_threads=$(top -n 1 -b -d 10 | grep -c cnvnator)
                sambamba_processes=$(top -n 1 -b -d 10 | grep -c sambamba)
                manta_processes=$(top -n 1 -b -d 10 | grep -c manta)
                breakseq_processes=$(top -n 1 -b -d 10 | grep -c breakseq)
                delly_processes=$(top -n 1 -b -d 10 | grep -c delly)
                lumpy_processes=$(top -n 1 -b -d 10 | grep -c lumpy)
                active_threads=$(python /getThreads.py "$breakdancer_threads" "$cnvnator_threads" "$sambamba_processes" "$manta_processes" "$breakseq_processes" "$delly_processes" "$lumpy_processes")
                sleep 60
            done
        fi
    done < contigs
fi

wait

# This is new
mkdir -p /home/dnanexus/out/stats
if [[ "$run_stats" == "True" ]]; then
    cp "${prefix}".AlignStatsReport.txt /home/dnanexus/out/stats/"${prefix}".AlignStatsReport.txt
    cp "${prefix}".AlignStatsReport.txt /home/dnanexus/out/stats/"${prefix}".AlignStatsReport.txt
    cp "${prefix}".flagstats /home/dnanexus/out/stats/"${prefix}".flagstats

    cp "${prefix}".chr1-8.selfSM /home/dnanexus/out/stats/"${prefix}".chr1-8.selfSM
    cp "${prefix}".chr1-8.depthSM /home/dnanexus/out/stats/"${prefix}".chr1-8.depthSM
    cp "${prefix}".chr9-15.selfSM /home/dnanexus/out/stats/"${prefix}".chr9-15.selfSM
    cp "${prefix}".chr9-15.depthSM /home/dnanexus/out/stats/"${prefix}".chr9-15.depthSM
    cp "${prefix}".chr16-Y.selfSM /home/dnanexus/out/stats/"${prefix}".chr16-Y.selfSM
    cp "${prefix}".chr16-Y.depthSM /home/dnanexus/out/stats/"${prefix}".chr16-Y.depthSM
fi

# This is new
mkdir -p /home/dnanexus/out/atlas
if [[ "$run_atlas" == "True" ]]; then
    bgzip "${prefix}"_indel.vcf
    tabix "${prefix}"_indel.vcf.gz
    bgzip "${prefix}"_snp.vcf
    tabix "${prefix}"_snp.vcf.gz

    cp "${prefix}"_snp.vcf.gz /home/dnanexus/out/atlas/"${prefix}".atlas.snp.vcf.gz
    cp "${prefix}"_indel.vcf.gz /home/dnanexus/out/atlas/"${prefix}".atlas.indel.vcf.gz
fi

# Only install SVTyper if necessary
if [[ "$run_genotype_candidates" == "True" ]]; then
    pip install git+https://github.com/hall-lab/svtyper.git -q &
fi

echo "Converting results to VCF format"
mkdir -p /home/dnanexus/out/sv_caller_results/

(if [[ "$run_lumpy" == "True" ]]; then
    echo "Convert Lumpy results to VCF format"
    python /convertHeader.py "$prefix" "$lumpy_merge_command" | vcf-sort -c | uniq > lumpy.vcf

    cp lumpy.vcf /home/dnanexus/out/sv_caller_results/"$prefix".lumpy.vcf

    python /vcf2bedpe.py -i lumpy.vcf -o lumpy.gff
    python /Lumpy2merge.py lumpy.gff "$prefix" 1.0
fi) &

(if [[ "$run_manta" == "True" ]]; then
    echo "Convert Manta results to VCF format"
    cp manta/results/variants/diploidSV.vcf.gz /home/dnanexus/out/sv_caller_results/"$prefix".manta.diploidSV.vcf.gz
    # cp manta/results/variants/candidateSV.vcf.gz /home/dnanexus/out/sv_caller_results/"$prefix".manta.candidateSV.vcf.gz
    cp manta/results/stats/alignmentStatsSummary.txt /home/dnanexus/out/sv_caller_results/"$prefix".manta.alignmentStatsSummary.txt

    mv manta/results/variants/diploidSV.vcf.gz .
    gunzip diploidSV.vcf.gz
    python /Manta2merge.py 1.0 diploidSV.vcf "$prefix"
fi) &

(if [[ "$run_breakdancer" == "True" ]] && [[ -n "$concat_breakdancer_cmd" ]]; then
    echo "Convert Breakdancer results to VCF format"
    # cat contents of each file into output file: lack of quotes intentional
    cat $concat_breakdancer_cmd > breakdancer.output

    cp breakdancer.output /home/dnanexus/out/sv_caller_results/"$prefix".breakdancer.ctx

    python /BreakDancer2Merge.py 1.0 breakdancer.output "$prefix"

    python /convert_breakdancer_vcf.py < breakdancer.output > breakdancer.vcf
    cp breakdancer.vcf /home/dnanexus/out/sv_caller_results/"$prefix".breakdancer.vcf
fi) &

(if [[ "$run_cnvnator" == "True" ]] && [[ -n "$concat_cnvnator_cmd" ]]; then
    echo "Convert CNVnator results to VCF format"
    # cat contents of each file into output file: lack of quotes intentional
    cat $concat_cnvnator_cmd > cnvnator.output

    perl /usr/utils/cnvnator2VCF.pl cnvnator.output > cnvnator.vcf

    cp cnvnator.vcf /home/dnanexus/out/sv_caller_results/"$prefix".cnvnator.vcf
    cp cnvnator.output /home/dnanexus/out/sv_caller_results/"$prefix".cnvnator.output
fi) &

(if [[ "$run_breakseq" == "True" ]]; then
    echo "Convert Breakseq results to VCF format"
    cd "$work" || return
    find ./*.log | tar -zcvf log.tar.gz -T -
    rm -rf ./*.log
    cd /home/dnanexus || return

    mv breakseq2/breakseq.vcf.gz .
    gunzip breakseq.vcf.gz

    cp breakseq2/breakseq_genotyped.gff /home/dnanexus/out/sv_caller_results/"$prefix".breakseq.gff
    cp breakseq.vcf /home/dnanexus/out/sv_caller_results/"$prefix".breakseq.vcf
    cp breakseq2/final.bam /home/dnanexus/out/sv_caller_results/"$prefix".breakseq.bam
fi) &

(if [[ "$run_delly_deletion" == "True" ]]; then 
    echo "Convert Delly deletion results to VCF format"
    python /convertHeader.py "$prefix" "$delly_deletion_concat" | vcf-sort -c | uniq > delly.deletion.vcf

    cp delly.deletion.vcf /home/dnanexus/out/sv_caller_results/"$prefix".delly.deletion.vcf
fi) &

(if [[ "$run_delly_inversion" == "True" ]]; then
    echo "Convert Delly inversion results to VCF format"
    python /convertHeader.py "$prefix" "$delly_inversion_concat" | vcf-sort -c | uniq > delly.inversion.vcf

    cp delly.inversion.vcf /home/dnanexus/out/sv_caller_results/"$prefix".delly.inversion.vcf
fi) &

(if [[ "$run_delly_duplication" == "True" ]]; then
    echo "Convert Delly duplication results to VCF format"
    python /convertHeader.py "$prefix" "$delly_duplication_concat" | vcf-sort -c | uniq > delly.duplication.vcf

    cp delly.duplication.vcf /home/dnanexus/out/sv_caller_results/"$prefix".delly.duplication.vcf
fi) &

(if [[ "$run_delly_insertion" == "True" ]]; then
    echo "Convert Delly insertion results to VCF format"
    python /convertHeader.py "$prefix" "$delly_insertion_concat" | vcf-sort -c | uniq > delly.insertion.vcf

    cp delly.insertion.vcf /home/dnanexus/out/sv_caller_results/"$prefix".delly.insertion.vcf
fi) &

wait

set -e
# Verify that there are VCF files available
if [[ -z $(find . -name "*.vcf") ]]; then
    if [[ "$dnanexus" == "True" ]]; then
        dx-jobutil-report-error "ERROR: SVTyper requested, but candidate VCF files required to genotype. No VCF files found."
    else
        echo "ERROR: SVTyper requested, but candidate VCF files required to genotype. No VCF files found."
        exit 1
    fi
fi
set +e

# Run SVtyper and SVviz
if [[ "$run_genotype_candidates" == "True" ]]; then
    echo "Running SVTyper"
    # SVviz and BreakSeq have mutually exclusive versions of pysam required, so
    # SVviz is only installed later and if necessary
    if [[ "$run_svviz" == "True" ]]; then
        pip install svviz -q &
    fi

    mkdir -p /home/dnanexus/out/svtyped_vcfs/

    i=0
    # Breakdancer
    if [[ "$run_breakdancer" == "True" ]]; then
        echo "Running SVTyper on Breakdancer outputs"
        mkdir /home/dnanexus/svtype_breakdancer
        bash ./parallelize_svtyper.sh /home/dnanexus/breakdancer.vcf svtype_breakdancer /home/dnanexus/"${prefix}".breakdancer.svtyped.vcf input.bam
        # timeout -k 500 60m bash ./parallelize_svtyper.sh /home/dnanexus/breakdancer.vcf svtype_breakdancer /home/dnanexus/"${prefix}".breakdancer.svtyped.vcf input.bam
    fi

    # Breakseq
    if [[ "$run_breakseq" == "True" ]]; then
        echo "Running SVTyper on BreakSeq outputs"
        mkdir /home/dnanexus/svtype_breakseq
        bash ./parallelize_svtyper.sh /home/dnanexus/breakseq.vcf svtype_breakseq /home/dnanexus/"${prefix}".breakseq.svtyped.vcf input.bam
        # timeout -k 500 60m bash ./parallelize_svtyper.sh /home/dnanexus/breakseq.vcf svtype_breakseq /home/dnanexus/"${prefix}".breakseq.svtyped.vcf input.bam

        if [[ -f breakseq.vcf ]]; then
            echo breakseq.vcf >> survivor_inputs
        fi
    fi

    # CNVnator
    if [[ "$run_cnvnator" == "True" ]]; then
        echo "Running SVTyper on CNVnator outputs"
        mkdir /home/dnanexus/svtype_cnvnator
        cat cnvnator.vcf | python /get_uncalled_cnvnator.py | python /add_ciend.py 1000 > /home/dnanexus/cnvnator.ci.vcf
        # timeout -k 500 60m bash ./parallelize_svtyper.sh /home/dnanexus/cnvnator.vcf svtype_cnvnator "${prefix}".cnvnator.svtyped.vcf input.bam
        bash ./parallelize_svtyper.sh /home/dnanexus/cnvnator.vcf svtype_cnvnator "${prefix}".cnvnator.svtyped.vcf input.bam
    fi

    # Delly
    if [[ "$run_delly" == "True" ]]; then
        echo "Running SVTyper on Delly outputs"
        for item in delly*vcf; do
            mkdir /home/dnanexus/svtype_delly_"$i"
            bash ./parallelize_svtyper.sh /home/dnanexus/"${item}" svtype_delly_"$i" /home/dnanexus/delly.svtyper."$i".vcf input.bam
            # timeout -k 500 60m bash ./parallelize_svtyper.sh /home/dnanexus/"${item}" svtype_delly_"$i" /home/dnanexus/delly.svtyper."$i".vcf input.bam
            i=$((i + 1))
        done

        grep \# delly.svtyper.0.vcf > "${prefix}".delly.svtyped.vcf

        for item in delly.svtyper*.vcf; do
            grep -v \# "$item" >> "${prefix}".delly.svtyped.vcf
        done
    fi

    # Lumpy
    if [[ "$run_lumpy" == "True" ]]; then
        echo "Running SVTyper on Lumpy outputs"
        mkdir /home/dnanexus/svtype_lumpy
        bash ./parallelize_svtyper.sh /home/dnanexus/lumpy.vcf svtype_lumpy /home/dnanexus/"${prefix}".lumpy.svtyped.vcf input.bam
        # timeout -k 500 60m bash ./parallelize_svtyper.sh /home/dnanexus/lumpy.vcf svtype_lumpy /home/dnanexus/"${prefix}".lumpy.svtyped.vcf input.bam
    fi

    # Manta
    if [[ "$run_manta" == "True" ]]; then
        # echo "Running SVTyper on Manta outputs"
        # zcat manta/results/variants/candidateSV.vcf.gz | python /add_ciend.py 100 > /home/dnanexus/manta.input.vcf
        # mkdir /home/dnanexus/svtype_manta
        # timeout -k 500 60m bash ./parallelize_svtyper.sh /home/dnanexus/manta.input.vcf svtype_manta /home/dnanexus/"${prefix}".manta.svtyped.vcf input.bam

        if [[ -f diploidSV.vcf ]]; then
            mv diploidSV.vcf /home/dnanexus/"${prefix}".manta.svtyped.vcf
            echo /home/dnanexus/"${prefix}".manta.svtyped.vcf >> survivor_inputs
        fi
    fi

    wait

    # Prepare inputs for SURVIVOR
    echo "Preparing inputs for SURVIVOR"
    for item in *svtyped.vcf; do
        python /adjust_svtyper_genotypes.py "$item" > adjusted.vcf
        mv adjusted.vcf "${item}"
        echo "${item}" >> survivor_inputs
    done

    # Prepare SVtyped VCFs for upload
    for item in *svtyped.vcf; do
        cp "$item" /home/dnanexus/out/svtyped_vcfs/$item
    done

    # Run SURVIVOR
    echo "Running SURVIVOR"
    survivor merge survivor_inputs 1000 1 1 0 0 10 survivor.output.vcf

    # Prepare SURVIVOR outputs for upload
    cat survivor.output.vcf | vcf-sort -c > survivor_sorted.vcf
    python /combine_combined.py survivor_sorted.vcf "$prefix" survivor_inputs /all.phred.txt | python /correct_max_position.py > /home/dnanexus/out/"$prefix".combined.genotyped.vcf

    # Run svviz
    if [[ "$run_svviz" == "True" ]]; then
        echo "Running svviz"
        mkdir svviz_outputs

        grep \# survivor_sorted.vcf > header.txt

        if [[ "$svviz_only_validated_candidates" == "True" ]]; then
            echo "Only visualizing validated candidates"
            grep -v \# survivor_sorted.vcf | grep -E -h "0/1|1/1" > vcf_entries.vcf
        else
            grep -v \# survivor_sorted.vcf > vcf_entries.vcf
        fi

        NUM_FILES=500
        vcf_entries=$(wc -l < vcf_entries.vcf | tr -d ' ')

        # Verify that there are VCF entries available to visualize
        if [[ $vcf_entries == 0 ]]; then
            # not throwing an error
            echo "No entries in the VCF to visualize. Not running svviz."
        else
            ((lines_per_file = (vcf_entries + NUM_FILES - 1) / NUM_FILES))
            split --lines=${lines_per_file} vcf_entries.vcf small_vcf.
            count=0

            for item in small_vcf*; do
                cat header.txt $item > survivor_split.${count}.vcf
                echo "timeout -k 100 5m svviz --pair-min-mapq 30 --max-deletion-size 5000 --max-reads 10000 --fast --type batch --summary svviz_summary.tsv -b input.bam ref.fa survivor_split.$count.vcf --export svviz_outputs 1>svviz.$count.stdout 2>svviz.$count.stderr" >> commands.txt
                ((count++))
            done
            
            threads="$(nproc)"
            threads=$((threads / 2))
            parallel --verbose -j $threads -a commands.txt eval 2> /dev/null
            
            tar -czf /home/dnanexus/out/"$prefix".svviz_outputs.tar.gz svviz_outputs/
        fi
    fi
fi