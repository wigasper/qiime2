# get that data
wget -O "sample-metadata.tsv" \
  	"https://data.qiime2.org/2020.2/tutorials/atacama-soils/sample_metadata.tsv"

mkdir emp-paired-end-sequences

wget -O "emp-paired-end-sequences/forward.fastq.gz" \
  	"https://data.qiime2.org/2020.2/tutorials/atacama-soils/10p/forward.fastq.gz"

wget -O "emp-paired-end-sequences/reverse.fastq.gz" \
  	"https://data.qiime2.org/2020.2/tutorials/atacama-soils/10p/reverse.fastq.gz"

wget -O "emp-paired-end-sequences/barcodes.fastq.gz" \
  	"https://data.qiime2.org/2020.2/tutorials/atacama-soils/10p/barcodes.fastq.gz"

########################################################################

export WORK_DIR="/home/wkg/repos/qiime2/atacama"

docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime tools import \
	--type EMPPairedEndSequences \ 
	--input-path emp-paired-end-sequences \ 
	--output-path emp-paired-end-sequences.qza
# single thread

# demux
docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime demux emp-paired \
	--m-barcodes-file sample-metadata.tsv \ 
	--m-barcodes-column barcode-sequence \ 
	--p-rev-comp-mapping-barcodes \ 
	--i-seqs emp-paired-end-sequences.qza \ 
	--o-per-sample-sequences demux.qza \
	--o-error-correction-details demux-details.qza
# seems to be single threaded
# takes awhile. not using much memory with this data

docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime demux summarize \
	--i-data demux.qza \
	--o-visualization demux.qzv
# single threaded. fast

# to look at the visualizations and summary tables from the demux:
docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime tools export \
	--input-path demux.qzv \
	--output-path demux_results

# this results in a directory that has a nice summary in HTML
# the heads of the reads are lower quality for both forward and 
# reverse. tails of reverse might be bad too? but going with 
# what the tutorial says

# trim and denoise
docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime dada2 denoise-paired \
	--i-demultiplexed-seqs demux.qza \ 
	--p-trim-left-f 13 \
	--p-trim-left-r 13 \
	--p-trunc-len-f 150 \
	--p-trunc-len-r 150 \
	--o-table table.qza \
	--o-representative-sequences rep-seqs.qza \
	--o-denoising-stats denoising-stats.qza
# single threaded

# generate summaries of feature table and sequences
docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime feature-table summarize \
	--i-table table.qza \
	--o-visualization table.qzv \
	--m-sample-metadata-file sample-metadata.tsv

docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime feature-table tabulate-seqs \
	--i-data rep-seqs.qza \
	--o-visualization rep-seqs.qzv

# generate denoising stats
docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime metadata tabulate \
	--m-input-file denoising-stats.qza \
	--o-visualization denoising-stats.qzv

# export results from the previous steps
docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime tools export \
	--input-path table.qzv \
	--output-path feature_table_viz

docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime tools export \
	--input-path rep-seqs.qzv \
	--output-path rep_seqs_viz

docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime tools export \
	--input-path denoising-stats.qzv \ 
	--output-path denoising_stats_viz

# generate phylogenetic tree
docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime phylogeny align-to-tree-mafft-fasttree \
	--i-sequences rep-seqs.qza \
	--o-alignment aligned-rep-seqs.qza \
	--o-masked-alignment masked-aligned_rep_seqs.qza \
	--o-tree unrooted-tree.qza \
	--o-rooted-tree rooted-tree.qza
# single threaded, fast

# alpha and beta diversity analysis
docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime diversity core-metrics-phylogenetic \
	--i-phylogeny rooted-tree.qza \
	--i-table table.qza \
	--p-sampling-depth 1000 \
	--m-metadata-file sample-metadata.tsv \
	--output-dir core-metrics-results
# this --p-sampling-depth param seems particularly important, need to read more about
# it. picked from the feature_table_viz to not exclude all samples

# check for associations between categorical metadata and alpha diversity
# not super useful for the atacama data
docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime diversity alpha-group-significance \
	--i-alpha-diversity core-metrics-results/faith_pd_vector.qza \
	--m-metadata-file sample-metadata.tsv \
	--o-visualization core-metrics-results/faith-pd-group-significance.qzv

docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime diversity alpha-group-significance \
	--i-alpha-diversity core-metrics-results/evenness_vector.qza \
	--m-metadata-file sample-metadata.tsv \
	--o-visualization core-metrics-results/evenness-group-significance.qzv

# export
docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime tools export \
	--input-path core-metrics-results/faith-pd-group-significance.qzv \ 
	--output-path core-metrics-results/faith-pd-group-significance

docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime tools export \
	--input-path core-metrics-results/evenness-group-significance.qzv \ 
	--output-path core-metrics-results/evenness-group-significance

# these results are quite interesting. distinct differences between 
# faith_pd and evenness

# this beta-group-significance requires column specification, going to 
# investigate vegetation
docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime diversity beta-group-significance \
	--i-distance-matrix core-metrics-results/unweighted_unifrac_distance_matrix.qza \
	--m-metadata-file sample-metadata.tsv \
	--m-metadata-column vegetation \
	--o-visualization core-metrics-results/unweighted-unifrac-vegetation-significance.qzv

docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime tools export \
	--input-path core-metrics-results/unweighted-unifrac-vegetation-significance.qzv \ 
	--output-path core-metrics-results/unweighted-unifrac-vegetation-significance


# to check for correlation of continuous metadata, going to try this
# lots of interesting variables here, just going to check out pH
# TODO: this could be automated to run for all continuous vars, as they 
# do for the categorical vars

# actually not going to check pH. 
# TODO: pH has missing values, need to figure out how to deal with this. 
# will try elevation first

# first need to create a distance matrix
# TODO: this will need to be organized better
docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime metadata distance-matrix \
	--m-metadata-file sample-metadata.tsv \
	--m-metadata-column elevation \
	--o-distance-matrix elevation-distance-matrix.qza

docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime diversity mantel \
	--i-dm1 elevation-distance-matrix.qza \
	--i-dm2 core-metrics-results/unweighted_unifrac_distance_matrix.qza \
	--p-label1 elevation \
	--p-label2 unifrac \
	--p-intersect-ids \
	--o-visualization mantel_elevation_test.qzv

docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime tools export \
	--input-path mantel_elevation_test.qzv \ 
	--output-path mantel_elevation_test

# clear correlation in the output and p=0.001

# skipping over alpha rarefaction plotting
# try the silva classifier
wget -O 'silva-132-99-515-806-nb-classifier.qza' \
	'https://data.qiime2.org/2020.2/common/silva-132-99-515-806-nb-classifier.qza'

docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime feature-classifier classify-sklearn \
	--i-classifier silva-132-99-515-806-nb-classifier.qza \ 
	--i-reads rep-seqs.qza \
	--o-classification taxonomy.qza
# takes awhile, uses 15gb ram for atacama data. 
# need to look at sklearn naive bayes implementation. some mulithread in prep but 
# compute is single threaded

docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime metadata tabulate \
	--m-input-file taxonomy.qza \
	--o-visualization taxonomy.qzv

docker run -t -i -v $WORK_DIR:/data qiime2/core:2020.2 \
	qiime tools export \
	--input-path taxonomy.qzv \ 
	--output-path taxonomy


