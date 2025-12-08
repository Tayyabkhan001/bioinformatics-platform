#!/usr/bin/env python3
import requests
import base64
import json
import time

# Your API Gateway endpoint
API_BASE_URL = "https://kqtg3kkrdf.execute-api.me-south-1.amazonaws.com/prod"

def test_upload():
    print("🚀 Testing Backend Upload Directly...")
    
    # Read and encode the test file
    with open("test_sequence.fastq", "rb") as f:
        file_content = base64.b64encode(f.read()).decode('utf-8')
    
    # Prepare the upload payload
    payload = {
        "fileName": "test_sequence.fastq",
        "fileContent": file_content,
        "analysisType": "fastqc",
        "userId": "manual-test-user"
    }
    
    print("📤 Sending upload request...")
    
    try:
        response = requests.post(
            f"{API_BASE_URL}/upload",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        
        print(f"📥 Response Status: {response.status_code}")
        print(f"📥 Response Body: {response.text}")
        
        if response.status_code == 200:
            result = response.json()
            job_id = result.get('jobId')
            print(f"✅ Upload Successful! Job ID: {job_id}")
            
            # Monitor job status
            monitor_job_status(job_id)
        else:
            print(f"❌ Upload Failed: {response.text}")
            
    except Exception as e:
        print(f"❌ Request Failed: {str(e)}")

def monitor_job_status(job_id):
    """Monitor job status until completion"""
    print(f"🔍 Monitoring job: {job_id}")
    
    for i in range(10):  # Check 10 times over 50 seconds
        try:
            response = requests.get(f"{API_BASE_URL}/jobs/{job_id}")
            
            if response.status_code == 200:
                job_data = response.json()
                status = job_data.get('status')
                batch_status = job_data.get('batchStatus', 'N/A')
                
                print(f"🔄 Check {i+1}: Status={status}, Batch Status={batch_status}")
                
                if status in ['COMPLETED', 'FAILED']:
                    print(f"🎯 Final Status: {status}")
                    
                    # Debug S3 files
                    debug_s3_files(job_id)
                    break
                    
            else:
                print(f"❌ Failed to get job status: {response.text}")
                
        except Exception as e:
            print(f"❌ Error checking job status: {str(e)}")
        
        time.sleep(5)  # Wait 5 seconds between checks

def debug_s3_files(job_id):
    """Check what files exist in S3 for this job"""
    print(f"📁 Checking S3 files for job: {job_id}")
    
    try:
        response = requests.get(
            f"{API_BASE_URL}/debug-s3",
            params={"jobId": job_id}
        )
        
        if response.status_code == 200:
            debug_data = response.json()
            files = debug_data.get('files', [])
            print(f"📦 Found {len(files)} files in S3:")
            for file in files:
                print(f"   - {file}")
        else:
            print(f"❌ Failed to debug S3: {response.text}")
            
    except Exception as e:
        print(f"❌ Error debugging S3: {str(e)}")

if __name__ == "__main__":
    test_upload()

