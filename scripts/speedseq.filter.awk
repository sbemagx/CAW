# somatic filter for FreeBayes VCF files, based on SpeedSeq: https://github.com/hall-lab/speedseq
# recommended to filter the large VCF files like: 
# vcfsamplediff -s VT normal tumour freebayesresult.vcf |egrep "#|somatic|loh" | vcffilter -f "QUAL > 20" | vcfflatten| awk -f ~/CAW/scripts/speedseq.filter.awk > filtered.vcf
# where "normal" and "tumour" are the sample names in the VCF respectively
# also check the index for these sample names also
BEGIN{
	MINQUAL=1;
	SSC_THRES=-100;	# somatic score threshold ssc = LOD_T + LOD_N, log of odds (LOD) is the genotype quality ratio (http://www.nature.com/nmeth/journal/v12/n10/pdf/nmeth.3505.pdf)
	ONLY_SOMATIC=1;	# prints out only somatic lines if not zero
	NORMAL=11;	# index of normal sample genotype 
	TUMOR=10; 	# index of tumor sample genotype
	GL_IDX=0;	# GL in the original: PL is the Normalized, Phred-scaled likelihoods for genotypes 
}
{
	OFS="\t";

    if ($0~"^#" && $0!~"^#CHROM") { print ; next; }
	# add extra header line
	if ($0~"^#CHROM") { 
			print "##INFO=<ID=DQUAL,Number=1,Type=Float,Description=\"SpeedSeq log of odds filter doi:10.1038/nmeth.3505 .\">"
			print ; 
	}
    if (! GL_IDX) {
        split($9,fmt,":")
        for (i=1;i<=length(fmt);++i) { if (fmt[i]=="GL") GL_IDX=i }
    }
    split($NORMAL,N,":");		# split field 10 and put values into 
    split(N[GL_IDX],NGL,",");
    split($TUMOR,T,":");
    split(T[GL_IDX],TGL,",");
    LOD_NORM=NGL[1]-NGL[2];
    LOD_TUMOR_HET=TGL[2]-TGL[1];
    LOD_TUMOR_HOM=TGL[3]-TGL[1];

    if (LOD_TUMOR_HET > LOD_TUMOR_HOM) { LOD_TUMOR=LOD_TUMOR_HET }
    else { LOD_TUMOR=LOD_TUMOR_HOM }

    DQUAL=LOD_TUMOR+LOD_NORM;

    if (DQUAL>=SSC_THRES && $NORMAL~"^0/0") {
        $7="PASS"
        $8="DQUAL="DQUAL";"$8
        print
    }
    else if (!ONLY_SOMATIC && $6>=MINQUAL && $10~"^0/0" && ! match($11,"^0/0")) {
        $8="DQUAL="DQUAL";"$8
        print
    }
}
