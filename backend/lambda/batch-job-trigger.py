import boto3
import json
import os

batch = boto3.client('batch')
s3 = boto3.client('s3')


def trigger_fastqc_analysis(job_id, s3_key):
    """Trigger real FastQC analysis via AWS Batch"""
    print(f"🔬 Triggering FastQC analysis for job {job_id}")

    try:
        response = batch.submit_job(
            jobName=f"fastqc-{job_id}",
            jobQueue="bioinformatics-queue",
            jobDefinition="fastqc-job",
            containerOverrides={
                'environment': [
                    {'name': 'JOB_ID', 'value': job_id},
                    {'name': 'S3_KEY', 'value': s3_key},
                    {'name': 'UPLOADS_BUCKET', 'value': os.environ['UPLOADS_BUCKET']},
                    {'name': 'RESULTS_BUCKET', 'value': os.environ['RESULTS_BUCKET']}
                ]
            }
        )
        print(f"✅ FastQC job submitted: {response['jobId']}")
        return response['jobId']
    except Exception as e:
        print(f"❌ Failed to submit FastQC job: {str(e)}")
        raise e


def trigger_blast_analysis(job_id, s3_key):
    """Trigger real BLAST analysis via AWS Batch"""
    print(f"🔍 Triggering BLAST analysis for job {job_id}")

    try:
        response = batch.submit_job(
            jobName=f"blast-{job_id}",
            jobQueue="bioinformatics-queue",
            jobDefinition="blast-job",
            containerOverrides={
                'environment': [
                    {'name': 'JOB_ID', 'value': job_id},
                    {'name': 'S3_KEY', 'value': s3_key},
                    {'name': 'UPLOADS_BUCKET', 'value': os.environ['UPLOADS_BUCKET']},
                    {'name': 'RESULTS_BUCKET', 'value': os.environ['RESULTS_BUCKET']}
                ]
            }
        )
        print(f"✅ BLAST job submitted: {response['jobId']}")
        return response['jobId']
    except Exception as e:
        print(f"❌ Failed to submit BLAST job: {str(e)}")
        raise e