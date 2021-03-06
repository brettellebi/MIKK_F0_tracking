# pull tracking parameters from config/samples.csv
def get_vid_length(wildcards):
    row = samples_df.loc[(samples_df['sample'] == wildcards.sample) & \
                         (samples_df['assay'] == wildcards.assay) & \
                         (samples_df['quadrant'] == wildcards.quadrant)]
    if wildcards.assay == "open_field":
        start = int(row['of_start'])
        end = int(row['of_end'])
    elif wildcards.assay == "novel_object":
        start = int(row['no_start'])
        end = int(row['no_end'])
    vid_length = int(end) - int(start)
    return(vid_length)

#def get_bgsub(wildcards):
#    if wildcards.assay == "open_field":
#        target_col = "bgsub_" + "of_" + wildcards.quadrant
#        bgsub = samples_df.loc[samples_df["sample"] == wildcards.sample, target_col].values[0]
#    elif wildcards.assay == "novel_object":
#        target_col = "bgsub_" + "no_" + wildcards.quadrant
#        bgsub = samples_df.loc[samples_df["sample"] == wildcards.sample, target_col].values[0]
#    return(bgsub)

def get_bgsub(wildcards):
    bgsub = samples_df.loc[(samples_df['sample'] == wildcards.sample) & \
                           (samples_df['assay'] == wildcards.assay) & \
                           (samples_df['quadrant'] == wildcards.quadrant), \
                           'bgsub'].values[0]
    return(bgsub)

def get_intensity_floor(wildcards):
    int_floor = samples_df.loc[(samples_df['sample'] == wildcards.sample) & \
                           (samples_df['assay'] == wildcards.assay) & \
                           (samples_df['quadrant'] == wildcards.quadrant), \
                           'intensity_floor'].values[0]
    return(int_floor)

def get_intensity_ceiling(wildcards):
    int_ceiling = samples_df.loc[(samples_df['sample'] == wildcards.sample) & \
                                 (samples_df['assay'] == wildcards.assay) & \
                                 (samples_df['quadrant'] == wildcards.quadrant), \
                                 'intensity_ceiling'].values[0]
    return(int_ceiling)

def get_area_floor(wildcards):
    area_floor = samples_df.loc[(samples_df['sample'] == wildcards.sample) & \
                                (samples_df['assay'] == wildcards.assay) & \
                                (samples_df['quadrant'] == wildcards.quadrant), \
                                'area_floor'].values[0]
    return(area_floor)

def get_area_ceiling(wildcards):
    area_ceiling = samples_df.loc[(samples_df['sample'] == wildcards.sample) & \
                                (samples_df['assay'] == wildcards.assay) & \
                                (samples_df['quadrant'] == wildcards.quadrant), \
                                'area_ceiling'].values[0]
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
        trajectories = os.path.join(
            config["working_dir"], 
            "split/{assay}/{sample}/session_{sample}_{quadrant}/trajectories/trajectories.npy"
        ),
        video_obj = os.path.join(
            config["working_dir"],
            "split/{assay}/{sample}/session_{sample}_{quadrant}/video_object.npy"
        ),
    log:
        os.path.join(
            config["working_dir"], 
            "logs/track_videos/{assay}/{sample}/{quadrant}.log"
        ),
    params:
        vid_length = get_vid_length,
        vid_name = "{sample}_{quadrant}",
        bgsub = get_bgsub,
        intensity_floor = get_intensity_floor,
        intensity_ceiling = get_intensity_ceiling,
        area_floor = get_area_floor,
        area_ceiling = get_area_ceiling,
    resources:
        mem_mb = lambda wildcards, attempt: attempt * 20000
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

def get_trajectories_file(wildcards):
    # Get path of trajectories files
    traj_wo_gaps_file = os.path.join(
        config["working_dir"],
        "split/{assay}/{sample}/session_{sample}_{quadrant}/trajectories_wo_gaps/trajectories_wo_gaps.npy")
    traj_file = os.path.join(
        config["working_dir"],
        "split/{assay}/{sample}/session_{sample}_{quadrant}/trajectories/trajectories.npy")
    # If there is no `trajectories_wo_gaps.npy` file, return the `trajectories.npy` file
    if os.path.exists(traj_wo_gaps_file):
        return(traj_wo_gaps_file)
    else:
        return(traj_file)

