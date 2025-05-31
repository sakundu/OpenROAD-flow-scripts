#!/bin/bash -i
source /home/sakundu/Script/open_road_setup
module unload anaconda3
module load anaconda3/23.3.1
source $CONDA_SH
conda activate /home/tool/anaconda/envs/cluster

export threshold="1.0"
export util=$1
export run_dir="${RESULTS_DIR}/blob_input"
export design="${DESIGN_NAME}"
export fanout=$2
export ar=$3
export DBU=$4

blob_dir="/home/memzfs_projects/BlobPlacement/sakundu/BlobPlacement/"
log_dir="${LOG_DIR}/blob_logs"
sed -i '/^DIEAREA/s@\(( 0 0 ) \)*@\1@g' ${run_dir}/${design}_placed.def
echo "Lef file is ${lef_files}"

# export lef_files="${run_dir}/28nm_12T.lef"
export output_dir="${RESULTS_DIR}/blob_run"
mkdir -p ${log_dir} ${output_dir}

# ## Run Clustering
echo "Starting the clustering job"
python3 ${blob_dir}/Clustering/gen_cluster_lef_def_test.py ${threshold} ${util} ${run_dir} ${design} ${ar} ${fanout} ${output_dir}
conda deactivate

echo "Starting the cluster placement job"
OR_EXE1="${blob_dir}/Scripts/openroad"
$OR_EXE1 ${blob_dir}/Scripts/or_place_clusters.tcl | tee ${log_dir}/or_place_clusters.log

conda activate /home/tool/anaconda/envs/cluster
echo "Starting the seeded placement input generation job"
python3 ${blob_dir}/Clustering/gen_seeded_palce.py ${threshold} ${util} ${run_dir} ${design} ${output_dir}
conda deactivate

sed -n "1,/UNITS DISTANCE MICRONS/p" ${output_dir}/${design}_cluster_placed_seeded.def > "${RESULTS_DIR}/${design}_seeded.def"
echo "" >> "${RESULTS_DIR}/${design}_seeded.def"
sed -n "/^COMPONENTS/,/END COMPONENTS/p" ${output_dir}/${design}_cluster_placed_seeded.def >> "${RESULTS_DIR}/${design}_seeded.def"
echo "" >> "${RESULTS_DIR}/${design}_seeded.def"
echo "END DESIGN" >> "${RESULTS_DIR}/${design}_seeded.def"
