#!/usr/bin/env python3
import boto3
import os
import subprocess
import json


def main():
    # Get environment variables
    job_id = os.environ['JOB_ID']
    s3_key = os.environ['S3_KEY']
    uploads_bucket = os.environ['UPLOADS_BUCKET']
    results_bucket = os.environ['RESULTS_BUCKET']

    print(f"🧬 Starting FastQC analysis for job: {job_id}")

    # Initialize S3 client
    s3 = boto3.client('s3')

    try:
        # Download input file from S3
        input_file = f"/tmp/{os.path.basename(s3_key)}"
        s3.download_file(uploads_bucket, s3_key, input_file)
        print(f"📥 Downloaded file: {input_file}")

        # Run FastQC
        output_dir = "/tmp/fastqc_output"
        os.makedirs(output_dir, exist_ok=True)

        cmd = ["fastqc", input_file, "-o", output_dir, "-f", "fastq"]
        print(f"🔧 Running: {' '.join(cmd)}")

        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode == 0:
            print("✅ FastQC analysis completed successfully")

            # Upload results to S3
            for file in os.listdir(output_dir):
                result_key = f"results/{job_id}/{file}"
                s3.upload_file(
                    os.path.join(output_dir, file),
                    results_bucket,
                    result_key
                )
                print(f"📤 Uploaded result: {result_key}")

            # Create summary
            summary = {
                "jobId": job_id,
                "status": "COMPLETED",
                "analysisType": "fastqc",
                "results": {
                    "htmlReport": f"results/{job_id}/fastqc_report.html",
                    "zipFile": f"results/{job_id}/fastqc_report.zip"
                },
                "message": "FastQC analysis completed successfully"
            }

            # Upload summary
            s3.put_object(
                Bucket=results_bucket,
                Key=f"results/{job_id}/summary.json",
                Body=json.dumps(summary)
            )

        else:
            print(f"❌ FastQC failed: {result.stderr}")
            raise Exception(f"FastQC analysis failed: {result.stderr}")

    except Exception as e:
        print(f"❌ Error in FastQC processing: {str(e)}")
        raise e


if __name__ == "__main__":
    main()