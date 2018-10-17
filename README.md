# Parliament2

Parliament2 identifies structural variants in a given sample relative to a reference genome. These structural variants cover large deletion events that are called as Deletions of a region, Insertions of a sequence into a region, Duplications of a region, Inversions of a region, or Translocations between two regions in the genome.

Parliament2 runs a combination of tools to generate structural variant calls on whole-genome sequencing data. It can run the following callers: Breakdancer, Breakseq2, CNVnator, Delly2, Manta, and Lumpy. Because of synergies in how the programs use computational resources, these are all run in parallel. Parliament2 will produce the outputs of each of the tools for subsequent investigation.

If the option to genotype candidates is selected, this tool will run SVTyper to genotype the events and will merge these tools with the program SURVIVOR. SV events that receive genotype calls have significantly higher specificity.

If the option to visualize candidates is selected, a `.tar.gz` file containing PDF images for each SV call will be produced in order to summarize the supporting information behind the SV.

## Getting Started

### Prerequisites

You must have [Docker](https://www.docker.com/) installed in order to run Parliament2. No other dependencies are required. Please see the Docker documentation for installation information.

### Installing

Parliament2 is meant to be run as a Docker image and is [available on DockerHub](https://hub.docker.com/r/dnanexus/parliament2/). The simplest way to install Parliament2 on your machine is to run the command `docker pull dnanexus/parliament2:<TAG>`, where the `<TAG>` is the version of Parliament2 you wish to use. You can see the full list of Parliament2 versions available on DockerHub at the [Parliament2 DockerHub repository](https://hub.docker.com/r/dnanexus/parliament2/tags/).

You can verify the successful installation using the command `docker images`, which will list every Docker image stored locally on your machine, or by running `docker run dnanexus/parliament2:<TAG> -h`, which will print the help string (printed in full at the bottom of this README).

#### Building from source

If you wish to build Parliament2 from source, you can find the most up-to-date production version of Parliament2 on our [release page](https://github.com/dnanexus/parliament2/releases) or pull from this repository (warning: this version may be unstable; the official releases will be more stable).

Once you have made your desired modifications (if applicable), run:

```
cd parliament2
tar -czvf resources.tar.gz resources/
docker build . -t parliament2
```

There should now be a Docker image named `parliament2` on your computer.

Again, you can verify the successful installation using the command `docker images`, which will list every Docker image stored locally on your machine, or by running `docker run parliament2 -h`, which will print the help string (printed in full at the bottom of this README).

## Running

### Required inputs

To run this Docker image, you must have:

* A local file with Illumina reads on which you want to call structural variants (`*.bam`)
* A reference genome file to which the BAM file was mapped (`*.fa.gz` or `*.fasta.gz`)

You may also have:

* The index for the BAM file (`*.bai`)
* The index for the reference genome file (`*.fai`)

This app is intended for whole-genome sequencing. Providing exome or panel sequencing will not produce good results. It is intended to be run on a single germline sample.

### Command-line call

To run Parliament2, use the following command-line call:

```
docker run -v <LOCAL_DIR_WITH_INPUTS>:/home/dnanexus/in -v <LOCAL_DIR_FOR_OUTPUTS>:/home/dnanexus/out dnanexus/parliament2:<TAG> --bam <BAM_NAME> --bai <INDEX_NAME> -r <REFERENCE_NAME> <OPTIONAL_ARGUMENTS>
```

You must mount two local volumes -- one that contains the inputs (`*.bam` and `*.fa.gz`) and one in which you wish to place the files generated by Parliament2. The `--bai` flag, along with the BAM index file, is optional, but including it will speed up runtime considerably. At least one optional argument must be specified; see below for more information on the optional arguments.

For example, if your current working directory is named `/home/dnanexus/` and looks like this:

```
.
├── input.bam
├── input.bai
├── ref_genome.fa.gz
└── outputs
```

where `outputs` is the directory you wish Parliament2 to place its results files, the command you would use to run Parliament2 could be:

```
docker run -v /home/dnanexus/:/home/dnanexus/in -v /home/dnanexus/outputs/:/home/dnanexus/out dnanexus/parliament2<TAG> --bam input.bam --bai input.bai -r ref_genome.fa.gz --breakdancer --cnvnator --manta --genotype
```

### Files generated

This app will output a number of files, representing the outputs of each of the structural variant callers. If the option to run a given step is unselected, then those outputs will not be provided.

- `lumpy.vcf`: representing the structural variant calls from Lumpy in VCF format.
- `lumpy.discordant.bam`: representing reads that Lumpy identified as discordant and used as evidence for its calls.
- `lumpy.splitters.bam`: representing reads that Lumpy identified as split-read mapped and used as evidence for its calls.
- `manta.diploidSV.vcf`: representing genotyped structural variant calls from Manta in VCF format.
- `manta.candidateSV.vcf`: representing candidate structural variant calls from Manta in VCF format.
- `manta.alignmentStats.txt`: representing statistics about the alignment from Manta.
- `breakdancer.ctx`: representing structural variant calls in Breakdancer's format.
- `cnvnator.output`: representing structural variant calls in CNVnator's format.
- `cnvnator.vcf`: representing structural variant calls from CNVnator in VCF format (this represents the conversion of CNVnator output to VCF format).
- `breakseq.gff`: representing structural variant calls from Breakseq2 in GFF format.
- `breakseq.vcf`: representing structural variant calls from Breakseq2 in VCF format.
- `breakseq.bam`: representing the reads mapping used as evidence for the calls generated by Breakseq2.
- `delly.deletion.vcf`: representing deletion calls made by Delly2.
- `delly.inversion.vcf`: representing inversion calls made by Delly2.
- `delly.duplication.vcf`: representing duplication calls made by Delly2.
- `delly.insertion.vcf`: representing insertion calls made by Delly2.
- `delly.translocation.vcf`: representing translocation calls made by Delly2.

- `<caller>.svtyped.vcf`: If the option to genotype candidates is selected, a genotype VCF produced by SVTyper will be generated for each caller output.
- `combined.genotyped.vcf`: If the option to genotype candidates is selected, a merged VCF file of all of the callers will be produced by SURVIVOR.

- `svviz_outputs.tar.gz`: If the option to visualize events is selected, a tarball containing a set of PDFs documenting the genomic regions for calls will be generated

## Running Parliament2 on DNAnexus

Parliament2 is available as an app on DNAnexus at https://platform.dnanexus.com/app/parliament2 (note: a DNAnexus account is required to access this link; you can create one at https://platform.dnanexus.com/login). The documentation for the app is included both on the DNAnexus platform and in the `dx_app_code` directory of this repository. A DNAnexus account is required to access the platform.

To run Parliament2 on DNAnexus, your input BAM file must be already on the DNAnexus platform. To run Parliament2 using the graphic interface, simply click the "Run" button from the app page and select your inputs. To run Parliament2 using the command-line interface, run the command `dx run parliament2 -h` and follow the guide generated. For more information on running executables on DNAnexus, see the [guide to running apps and applets](https://wiki.dnanexus.com/Command-Line-Client/Running-Apps-and-Applets).

General information on using DNAnexus can be found in the [official documentation](https://wiki.dnanexus.com/Home).

### Building Parliament2 on DNAnexus

To build Parliament2 on your own on DNAnexus, you will have to have built the Docker image locally (see [Installing](#installing)). Then:

* Run `dx-docker create-asset parliament2`. This will take approximately 45 minutes and will generate a string that you can copy-paste into the `dxapp.json` file found in the `dx_app_code/parliament2` directory under the "Regional Options" section for your region.

* Run `dx build parliament2` to build the applet from within the `dx_app_code` directory.

For more information about using DNAnexus, see the following links:

* [Tutorial for using Docker images on DNAnexus](https://wiki.dnanexus.com/Developer-Tutorials/Using-Docker-Images)
* [Tutorial for building apps on DNAnexus](https://wiki.dnanexus.com/Developer-Tutorials/Intro-to-Building-Apps) 

General information on using DNAnexus can be found in the [official documentation](https://wiki.dnanexus.com/Home).

#### Modifying Parliament2 on DNAnexus

To modify Parliament2 and run it on DNAnexus, please see the developer README in the `dx_app_code/parliament2` directory of this repository.

## More Information

### Tool versions

#### Structural variant callers
* Breakdancer: [v1.4.3](https://github.com/genome/breakdancer/releases/tag/v1.4.3)
* BreakSeq2: [v2.2](http://bioinform.github.io/breakseq2/)
* CNVnator: [v0.3.3](https://github.com/abyzovlab/CNVnator/commit/de012f2bccfd4e11e84cf685b19fc138115f2d0d)
* Delly: [v0.7.2](https://github.com/dellytools/delly/releases/tag/v0.7.2)
* Lumpy: [v0.2.13](https://github.com/arq5x/lumpy-sv/commit/f466f61e02680796192b055e4c084fbb23dcc692)
* Manta: [v1.4.0](https://anaconda.org/bioconda/manta)

#### Other tools
* SVTyper: [v0.7.0](https://github.com/hall-lab/svtyper/commit/5fc30763fd3025793ee712a563de800c010f6bea)
* svviz: [v1.5.2](https://github.com/svviz/svviz/commit/84acefa13bf0d4ad6e7e0f1d058aed6f16681142)
* SURVIVOR: [v1.0.3](https://github.com/fritzsedlazeck/SURVIVOR/commit/7c7731d71fa1cba017f470895fb3ef55f2812067)

### Additional notes

Because the field of structural variation is relatively new and complex, we viewed placing a dependency on all individual tools completing successfully as a requirement for a successful run to be too strict. In other words, if one of these tools fails while the others succeed, the app will output the results of the tools that completed and will not itself fail.

Breakseq2 may only be able to work when using the 1000 Genomes reference genome (hs37d5). For other reference genomes, you may not get Breakseq2 results.

### Supporting information

For additional information, please see the following papers:

- Lumpy: Ryan M Layer, Colby Chiang, Aaron R Quinlan, and Ira M Hall. 2014. "LUMPY: a Probabilistic Framework for Structural Variant Discovery." Genome Biology 15 (6): R84. doi:10.1186/gb-2014-15-6-r84
- Manta: Chen X, Schulz-Trieglaff O, Shaw R, Barnes B, Schlesinger F, Källberg M, Cox AJ, Kruglyak S, Saunders CT. 2015 "Manta: rapid detection of structural variants and indels for germline and cancer sequencing applications." Bioinformatics. doi: 10.1093/bioinformatics/btv710
- Breakdancer: Chen K, Wallis JW, McLellan MD, Larson DE, Kalicki JM, Pohl CS, McGrath SD, Wendl MC, Zhang Q, Locke DP, Shi X, Fulton RS, Ley TJ, Wilson RK, Ding L, Mardis ER. 2009. "BreakDancer: an algorithm for high-resolution mapping of genomic structural variation". Nature Methods 6. doi:10.1038/nmeth.1363
- Breakseq2: Abyzov A, Li S, Kim DR, Mohiyuddin M, Stütz AM, Parrish NF, Mu XJ, Clark W, Chen K, Hurles M, Korbel JO, Lam HYK, Lee C, Gerstein MB. 2015. "Analysis of deletion breakpoints from 1,092 humans reveals details of mutation mechanisms". Nature Communications 6. doi:10.1038/ncomms8256
- Delly2: Tobias Rausch, Thomas Zichner, Andreas Schlattl, Adrian M. Stuetz, Vladimir Benes, Jan O. Korbel. 2012. Delly: structural variant discovery by integrated paired-end and split-read analysis. Bioinformatics 28:i333-i339. doi: 10.1093/bioinformatics/bts378
- CNVnator: Abyzov A, Urban AE, Snyder M, Gerstein M. 2011. "CNVnator: an approach to discover, genotype, and characterize typical and atypical CNVs from family and population genome sequencing". Genome Research (6):974. doi: 10.1101/gr.114876.110
- Parliament: Adam C English, William J Salerno, Oliver A Hampton, Claudia Gonzaga-Jauregui, Shruthi Ambreth, Deborah I Ritter, Christine R Beck, Caleb F Davis, Mahmoud Dahdouli, Singer Ma, Andrew Carroll, Narayanan Veeraraghavan, Jeremy Bruestle, Becky Drees, Alex Hastie, Ernest T Lam, Simon White, Pamela Mishra, Min Wang, Yi Han, Feng Zhang, Pawel Stankiewicz, David A Wheeler, Jeffrey G Reid, Donna M Muzny, Jeffrey Rogers, Aniko Sabo, Kim C Worley, James R Lupski, Eric Boerwinkle and Richard A Gibbs. Assessing structural variation in a personal genome—towards a human reference diploid genome. BMC Genomics 2015, 16:286  doi:10.1186/s12864-015-1479-3.

## Help

```
usage: parliament2.py [-h] --bam BAM [--bai BAI] -r REF_GENOME [--fai FAI]
                      [--prefix PREFIX] [--filter_short_contigs]
                      [--breakdancer] [--breakseq] [--manta] [--cnvnator]
                      [--lumpy] [--delly_deletion] [--delly_insertion]
                      [--delly_inversion] [--delly_duplication] [--genotype]
                      [--svviz] [--svviz_only_validated_candidates]

Parliament2

optional arguments:
  -h, --help            show this help message and exit
  --bam BAM             The name of the Illumina BAM file for which to call
                        structural variants containing mapped reads.
  --bai BAI             (Optional) The name of the corresponding index for the
                        Illumina BAM file.
  -r REF_GENOME, --ref_genome REF_GENOME
                        The name of the reference file that matches the
                        reference used to map the Illumina inputs.
  --fai FAI             (Optional) The name of the corresponding index for the
                        reference genome file.
  --prefix PREFIX       (Optional) If provided, all output files will start
                        with this. If absent, the base of the BAM file name
                        will be used.
  --filter_short_contigs
                        If selected, SV calls will not be generated on contigs
                        shorter than 1 MB.
  --breakdancer         If selected, the program Breakdancer will be one of
                        the SV callers run.
  --breakseq            If selected, the program BreakSeq2 will be one of the
                        SV callers run.
  --manta               If selected, the program Manta will be one of the SV
                        callers run.
  --cnvnator            If selected, the program CNVnator will be one of the
                        SV callers run.
  --lumpy               If selected, the program Lumpy will be one of the SV
                        callers run.
  --delly_deletion      If selected, the deletion module of the program Delly2
                        will be one of the SV callers run.
  --delly_insertion     If selected, the insertion module of the program
                        Delly2 will be one of the SV callers run.
  --delly_inversion     If selected, the inversion module of the program
                        Delly2 will be one of the SV callers run.
  --delly_duplication   If selected, the duplication module of the program
                        Delly2 will be one of the SV callers run.
  --genotype            If selected, candidate events determined from the
                        individual callers will be genotyped and merged to
                        create a consensus output.
  --svviz               If selected, visualizations of genotyped SV events
                        will be produced with SVVIZ, one screenshot of support
                        per event. For this option to take effect, Genotype
                        must be selected.
  --svviz_only_validated_candidates
                        Run SVVIZ only on validated candidates? For this
                        option to be relevant, SVVIZ must be selected. NOT
                        selecting this will make the SVVIZ component run
                        longer.
```
