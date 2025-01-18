#!/bin/bash

# Set the source directory from which to start converting videos
SOURCE_DIR="$1"
LOG_FILE="conversion_log.txt"
SUMMARY_FILE="conversion_summary.txt"

# Initialize log and summary files
> "$LOG_FILE"
> "$SUMMARY_FILE"

# Initialize counters
success_count=0
fail_count=0

mapfile -t all_files < <(find "$SOURCE_DIR" -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.mov" \))
total_files=${#all_files[@]}
processed_count=0

# Function to process videos recursively
process_videos() {
  for video_file in "${all_files[@]}"; do
    if [[ -f "$video_file".converted.mp4 ]]; then
      echo "Skipping already processed: $video_file" | tee -a "$LOG_FILE"
      continue
    fi

    ((processed_count++))
    output_file="$video_file.converted.mp4"

    start_time=$(date +%s)
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    echo "[$timestamp] Processing ($processed_count/$total_files): $video_file" | tee -a "$LOG_FILE"

    retry=0
    max_retries=2
    success=false

    while [ $retry -le $max_retries ]; do
      HandBrakeCLI -i "$video_file" -o "$output_file" -e nvenc_h265_10bit --quality 35 >> "$LOG_FILE" 2>&1
      if [ $? -eq 0 ]; then
        echo "[$timestamp] Successfully converted: $video_file" | tee -a "$LOG_FILE"
        mv "$output_file" "$video_file"  # Replace the original video with the converted one
        ((success_count++))
        success=true
        break
      else
        ((retry++))
        echo "[$timestamp] Retry $retry for: $video_file" | tee -a "$LOG_FILE"
      fi
    done

    if [ "$success" = false ]; then
      echo "[$timestamp] Failed to convert after retries: $video_file" | tee -a "$LOG_FILE"
      rm -f "$output_file"
      ((fail_count++))
    fi

    end_time=$(date +%s)
    duration=$((end_time - start_time))
    echo "[$timestamp] Time taken for $video_file: $duration seconds" | tee -a "$LOG_FILE"
  done
}

if [ -z "$SOURCE_DIR" ]; then
  echo "Usage: $0 <source_directory>"
  exit 1
fi

process_videos

echo "Conversion complete. Summary:" | tee -a "$LOG_FILE" "$SUMMARY_FILE"
echo "Successful conversions: $success_count" | tee -a "$LOG_FILE" "$SUMMARY_FILE"
echo "Failed conversions: $fail_count" | tee -a "$LOG_FILE" "$SUMMARY_FILE"
