import React, { useState, useEffect, useRef } from 'react';
import UploadForm from './components/UploadForm';
import JobDashboard from './components/JobDashboard';
import { bioinformaticsAPI, adaptJob, mapApiStatusToFrontend } from './services/api';
import './App.css';

export interface Job {
  id: string;
  type: string;
  status: 'pending' | 'running' | 'completed' | 'error';
  filename: string;
  createdAt: Date;
  batchJobId?: string;
}

function App() {
  const [jobs, setJobs] = useState<Job[]>([]);
  const jobsRef = useRef<Job[]>(jobs);

  useEffect(() => {
    jobsRef.current = jobs;
  }, [jobs]);

  const mapAPIJobToFrontend = (apiJob: any): Job => {
    console.log('🔄 Mapping API job to frontend:', {
      apiJobId: apiJob.jobId,
      apiStatus: apiJob.status,
      apiAnalysisType: apiJob.analysisType,
      apiFileName: apiJob.fileName
    });

    const frontendJob: Job = {
      id: apiJob.jobId || apiJob.id,
      type: apiJob.analysisType || apiJob.type || 'unknown',
      status: mapApiStatusToFrontend(apiJob.status),
      filename: apiJob.fileName || apiJob.filename || 'unknown',
      createdAt: apiJob.createdAt ? new Date(apiJob.createdAt) : new Date(),
      batchJobId: apiJob.batchJobId,
    };

    console.log('✅ Mapped frontend job:', frontendJob);
    return frontendJob;
  };

  const pollJobStatus = async (jobId: string) => {
    try {
      console.log(`🔍 Polling job status: ${jobId}`);
      const apiJob = await bioinformaticsAPI.getJob(jobId);

      console.log('📊 RAW API RESPONSE:', apiJob);

      const frontendJob = mapAPIJobToFrontend(apiJob);

      setJobs(prev => {
        const updatedJobs = prev.map(j => (j.id === jobId ? frontendJob : j));
        console.log('🔄 Updated jobs state:', updatedJobs);
        return updatedJobs;
      });

      return (
        frontendJob.status === 'completed' ||
        frontendJob.status === 'error'
      );
    } catch (error) {
      console.warn(`⚠️ Polling job ${jobId} failed:`, error);
      return false;
    }
  };

  useEffect(() => {
    let isMounted = true;

    const pollActiveJobs = async () => {
      if (!isMounted) return;

      const jobsToPoll = jobsRef.current.filter(
        job => job.status === 'pending' || job.status === 'running'
      );

      if (jobsToPoll.length > 0) {
        console.log(`⏳ Polling ${jobsToPoll.length} active jobs...`);
        const pollingPromises = jobsToPoll.map(job => pollJobStatus(job.id));
        await Promise.allSettled(pollingPromises);
      }
    };

    const interval = setInterval(pollActiveJobs, 5000);
    pollActiveJobs();

    return () => {
      isMounted = false;
      clearInterval(interval);
    };
  }, []);

  const handleUpload = async (file: File, analysisType: string) => {
    console.log('📤 Starting upload for file:', file.name, 'analysis:', analysisType);

    try {
      const uploadedApiJob = await bioinformaticsAPI.uploadFile(
        file,
        analysisType as 'fastqc' | 'blast'
      );

      const newJob: Job = {
        id: uploadedApiJob.id,
        type: uploadedApiJob.type,
        status: uploadedApiJob.status,
        filename: uploadedApiJob.filename,
        createdAt: uploadedApiJob.createdAt,
        batchJobId: uploadedApiJob.batchJobId,
      };

      console.log('✅ Job created:', newJob);

      setJobs(prev => [newJob, ...prev]);

      setTimeout(() => pollJobStatus(newJob.id), 2000);
    } catch (error) {
      console.error('❌ Upload failed:', error);
      alert('Upload failed. Please check the file and try again.');
    }
  };

  // ============================
  // ✅ NCBI FETCH JOB CALLBACK
  // ============================
  const handleNCBIJobCreated = (job: Job) => {
    setJobs(prev => [job, ...prev]);
    pollJobStatus(job.id);
  };

  const DebugPanel = () => (
    <div
      style={{
        background: '#f8f9fa',
        padding: '15px',
        margin: '15px 0',
        border: '2px solid #dee2e6',
        borderRadius: '8px',
        fontSize: '13px',
        fontFamily: 'monospace'
      }}
    >
      <h4 style={{ margin: '0 0 10px 0', color: '#495057' }}>
        🔧 Debug Panel (Jobs: {jobs.length})
      </h4>
      {jobs.length === 0 ? (
        <div style={{ color: '#6c757d', fontStyle: 'italic' }}>No jobs to display</div>
      ) : (
        jobs.map(job => (
          <div
            key={job.id}
            style={{
              margin: '8px 0',
              padding: '8px',
              background: '#fff',
              border: '1px solid #e9ecef',
              borderRadius: '4px'
            }}
          >
            <div><strong>📄 {job.filename}</strong></div>
            <div>🆔 ID: {job.id.substring(0, 12)}...</div>
            <div>📊 Status: {job.status.toUpperCase()}</div>
            <div>🔬 Type: {job.type.toUpperCase()}</div>
            <div>⏰ Created: {job.createdAt.toLocaleString()}</div>
            {job.batchJobId && <div>⚙️ Batch: {job.batchJobId.substring(0, 12)}...</div>}
          </div>
        ))
      )}
    </div>
  );

  return (
    <div className="App">
      <header className="App-header">
        <h1>🧬 Bioinformatics Analysis Platform</h1>
        <p>Cloud-native sequence analysis and visualization</p>
      </header>

      <main>
        <UploadForm
          onUpload={handleUpload}
          onJobCreated={handleNCBIJobCreated}
        />

        <DebugPanel />
        <JobDashboard jobs={jobs} />
      </main>
    </div>
  );
}

export default App;
