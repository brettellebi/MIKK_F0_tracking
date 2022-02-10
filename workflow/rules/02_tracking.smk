# pull tracking parameters from config/samples.csv
def get_vid_length(wildcards):
    if wildcards.assay == "open_field":
        start = samples_df.loc[samples_df["sample"] == wildcards.sample, "of_start"]
        end = samples_df.loc[samples_df["sample"] == wildcards.sample, "of_end"]
    elif wildcards.assay == "novel_object":
        start = samples_df.loc[samples_df["sample"] == wildcards.sample, "no_start"]
        end = samples_df.loc[samples_df["sample"] == wildcards.sample, "no_end"]
    vid_length = int(end) - int(start)
    return(vid_length)

def get_bgsub(wildcards):
    if wildcards.assay == "open_field":
        bgsub = samples_df.loc[samples_df["sample"] == wildcards.sample, "bgsub_of"].values[0]
    elif wildcards.assay == "novel_object":
        bgsub = samples_df.loc[samples_df["sample"] == wildcards.sample, "bgsub_no"].values[0]
    return(bgsub)

def get_intensity_floor(wildcards):
    if wildcards.assay == "open_field":
        int_floor = int(samples_df.loc[samples_df["sample"] == wildcards.sample, "intensity_floor_of"])
    elif wildcards.assay == "novel_object":
        int_floor = int(samples_df.loc[samples_df["sample"] == wildcards.sample, "intensity_floor_no"])
    return(int_floor)

def get_intensity_ceiling(wildcards):
    if wildcards.assay == "open_field":
        int_ceiling = int(samples_df.loc[samples_df["sample"] == wildcards.sample, "intensity_ceiling_of"])
    elif wildcards.assay == "novel_object":
        int_ceiling = int(samples_df.loc[samples_df["sample"] == wildcards.sample, "intensity_ceiling_no"])
    return(int_ceiling)

def get_area_floor(wildcards):
    if wildcards.assay == "open_field":
        area_floor = int(samples_df.loc[samples_df["sample"] == wildcards.sample, "area_floor_of"])
    elif wildcards.assay == "novel_object":
        area_floor = int(samples_df.loc[samples_df["sample"] == wildcards.sample, "area_floor_no"])
    return(area_floor)

def get_area_ceiling(wildcards):
    if wildcards.assay == "open_field":
        area_ceiling = int(samples_df.loc[samples_df["sample"] == wildcards.sample, "area_ceiling_of"])
    elif wildcards.assay == "novel_object":
        area_ceiling = int(samples_df.loc[samples_df["sample"] == wildcards.sample, "area_ceiling_no"])
    return(area_ceiling)

# adapt memory usage for tracking videos
def get_mem_mb(wildcards, attempt):
    return attempt * 10000

# Track videos with idtrackerai
## Note: `output` is set as `trajectories.npy` instead of `trajectories_wo_gaps.npy`, presumably because
## in videos where there are no crossovers, the latter file is not produced.
rule track_videos:
    input:
        rules.split_videos.output
    output:
        os.path.join(config["data_store_dir"], "split/{assay}/session_{sample}_{quadrant}/trajectories/trajectories.npy"),
    log:
        os.path.join(config["working_dir"], "logs/track_videos/{assay}/{sample}/{quadrant}.log"),
    params:
        vid_length = get_vid_length,
        vid_name = "{sample}_{quadrant}",
        bgsub = get_bgsub,
        intensity_floor = get_intensity_floor,
        intensity_ceiling = get_intensity_ceiling,
        area_floor = get_area_floor,
        area_ceiling = get_area_ceiling,
    resources:
        mem_mb = get_mem_mb
    container:
        config["idtrackerai"]
    shell:
        """
        idtrackerai terminal_mode \
            --_video {input} \
            --_bgsub '{params.bgsub}' \
            --_range [0,{params.vid_length}] \
            --_intensity [{params.intensity_floor},{params.intensity_ceiling}] \
            --_area [{params.area_floor},{params.area_ceiling}] \
            --_session {params.vid_name} \
            --exec track_video \
                2> {log}
        """

# Convert numpy arrays to .csv files
rule trajectories_to_csv:
    input:
        trajectories = rules.track_videos.output,
        script = "workflow/scripts/trajectories_to_csv.py"
    output:
        os.path.join(config["data_store_dir"], "split/{assay}/session_{sample}_{quadrant}/trajectories/trajectories.trajectories.csv")
    log:
        os.path.join(config["working_dir"], "logs/trajectories_to_csv/{assay}/{sample}/{quadrant}.log"),
    params:
        in_path = os.path.join(config["data_store_dir"], "split/{assay}/session_{sample}_{quadrant}")
    shell:
        """
        python {input.script} {params.in_path}
        """

def get_final_csvs(wildcards):
    # Get path of csv files
    traj_wo_gaps_file = os.path.join(config["data_store_dir"], "split/{assay}/session_{sample}_{quadrant}/trajectories_wo_gaps/trajectories_wo_gaps.trajectories.csv")
    traj_file = os.path.join(config["data_store_dir"], "split/{assay}/session_{sample}_{quadrant}/trajectories/trajectories.trajectories.csv")
    # If there is no "without gaps" file, return the 
    if os.path.exists(traj_wo_gaps_file):
        return(traj_wo_gaps_file)
    else:
        return(traj_file)