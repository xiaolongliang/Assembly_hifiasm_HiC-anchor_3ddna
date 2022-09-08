#!/bin/bash
## assembly software: hifiasm
## Hic-anchor software: juicer, 3DDNA

#- workdir
#	- Hifi_input/
#	- HiC_input/	
#	- Hifi_output/ 新建
#	- juicer_output/ 新建 

##有参shell
#while getopts ':hifi:hic:cpu:' opt
#do
#	case $opt in
#		hifi)
#			Hifi_input=$OPTARG
#			;;
#		hic)
#			HiC_input=$OPTARG
#			;;
#		cpu)
#			CPU=$OPTARG
#			;;
#		?)
#			echo "Usage: assembly_anchor.sh -hifi hifi_dir -hic hic_dir -cpu cpu"
#			exit 1
#			;;
#	esac
#done

Hifi_input=$1
HiC_input=$2
CPU=$3

workdir="$(pwd)"
Prefix="DWR_Pika07"

juicer="/home/liangxl21/software/juicer-1.6"
ddna3="/home/liangxl21/software/3d-dna"

# Assembly
## create Assembly_OUTPUT directory
if [ ! -d "${workdir}/Assembly_OUTPUT" ];then
	mkdir ${workdir}/Assembly_OUTPUT
else
	break
fi

hifiasm -o ${workdir}/Assembly_OUTPUT/$Prefix -t $CPU $(echo ${workdir}/${Hifi_input}/*) && echo "**** hifiasm done! ****"
awk '/^S/{print">"$2;print $3}' ${workdir}/Assembly_OUTPUT/$Prefix.bp.p_ctg.gfa > ${workdir}/Assembly_OUTPUT/$Prefix.bp.p_ctg.fasta && echo "**** ${Prefix}.bp.p_ctg.fasta done! ***"

# Index 
bwa index ${workdir}/Assembly_OUTPUT/$Prefix.bp.p_ctg.fasta && echo "**** bwa index done! ****"

# Hic-anchor
## juicer

### create juicer_output & data directory and move Hi-C data to data directory
if [ ! -d "${workdir}/juicer_output" ];then
	mkdir -p ${workdir}/juicer_output/data/fastq
	ln -s ${workdir}/${HiC_input}/* ${workdir}/juicer_output/data/fastq
else
	break
fi

### 创建酶切位点文件
python ${juicer}/misc/generate_site_positions.py MboI $Prefix ${workdir}/Assembly_OUTPUT/$Prefix.bp.p_ctg.fasta && echo "**** ${Prefix}_MboI.txt done! ****"
mv ${workdir}/${Prefix}_MboI.txt ${workdir}/juicer_output

### 计算contig长度
awk 'BEGIN{OFS="\t"}{print $1, $NF}' ${workdir}/juicer_output/${Prefix}_MboI.txt > ${workdir}/juicer_output/${Prefix}.chrom.sizes && echo "**** ${Prefix}.chrom.sizes done! ****"

${juicer}/scripts/juicer.sh \
	-z ${workdir}/Assembly_OUTPUT/$Prefix.bp.p_ctg.fasta\
	-p ${workdir}/juicer_output/genome.chrom.sizes \
	-y ${workdir}/juicer_output/DWR_Pika07_MboI.txt \
	-d ${workdir}/juicer_output/data \
	-D $juicer \
	-g $Prefix \
	-s MboI \
	-t $CPU \
	-S early && echo "**** juicer done! ****"

## 3DDNA
${ddna3}/run-asm-pipeline.sh \
	-r 2 \
	--sort-output ${workdir}/Assembly_OUTPUT/$Prefix.bp.p_ctg.fasta \
	${workdir}/juicer_output/data/aligned/merged_nodups.txt && echo "**** 3DDNA done! ****"
