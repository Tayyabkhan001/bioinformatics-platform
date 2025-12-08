import axios from 'axios';

const API_BASE_URL = 'https://kqtg3kkrdf.execute-api.me-south-1.amazonaws.com/prod';

console.log('🔗 API Base URL:', API_BASE_URL);

export interface UploadRequest {
  fileName: string;
  fileContent: string; // Base64
  analysisType: 'fastqc' | 'blast';
  userId?: string;
}

export interface NCBIFetchRequest {
  accessionId: string;
  analysisType: 'fastqc' | 'blast';
  userId?: string;
}

export interface JobResponse {
  jobId: string;
  userId?: string;
  fileName?: string;
  analysisType?: string;
  status: 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED';
  message?: string;
  s3Key?: string;
  timestamp?: string;
  createdAt?: string;
  updatedAt?: string;
  batchJobId?: string;
  resultFiles?: string[];
  availableFiles?: {
    html?: string;
    zip?: string;
    txt?: string;
    fasta?: string;
    summary?: string;
  };
  accessionId?: string; // For NCBI jobs
}

export interface DownloadResponse {
  downloadUrl: string;
  fileKey: string;
  expiresIn: string;
  note: string;
}

export interface Job {
  id: string;
  filename: string;
  type: string;
  status: 'pending' | 'running' | 'completed' | 'error';
  createdAt: Date;
  userId?: string;
  batchJobId?: string;
  accessionId?: string; // For NCBI jobs
}

// ✅ ENHANCED: Better status mapping with debugging
export const mapApiStatusToFrontend = (apiStatus: string): Job['status'] => {
  console.log('🔄 Mapping API status:', apiStatus);

  const mapping: { [key: string]: Job['status'] } = {
    'PENDING': 'pending',
    'PROCESSING': 'running',
    'RUNNING': 'running',
    'COMPLETED': 'completed',
    'SUCCEEDED': 'completed',
    'FAILED': 'error',
    'ERROR': 'error'
  };

  const mappedStatus = mapping[apiStatus] || 'pending';
  console.log('🎯 Mapped to frontend status:', mappedStatus);
  return mappedStatus;
};

// ✅ ENHANCED: Adapter with better debugging
export const adaptJob = (lambdaJob: JobResponse): Job => {
  console.log('🔄 Adapting Lambda job to frontend job:', lambdaJob);

  const adaptedJob: Job = {
    id: lambdaJob.jobId,
    filename: lambdaJob.fileName || 'NCBI: ' + (lambdaJob.accessionId || 'Unknown'),
    type: lambdaJob.analysisType || 'unknown',
    status: mapApiStatusToFrontend(lambdaJob.status),
    createdAt: new Date(lambdaJob.createdAt || lambdaJob.timestamp || Date.now()),
    userId: lambdaJob.userId,
    batchJobId: lambdaJob.batchJobId,
    accessionId: lambdaJob.accessionId
  };

  console.log('✅ Adapted job:', adaptedJob);
  return adaptedJob;
};

class BioinformaticsAPI {
  private client = axios.create({
    baseURL: API_BASE_URL,
    headers: { 'Content-Type': 'application/json' },
    timeout: 30000,
  });

  async uploadFile(file: File, analysisType: 'fastqc' | 'blast'): Promise<Job> {
    try {
      const fileContent = await this.fileToBase64(file);
      const request: UploadRequest = {
        fileName: file.name,
        fileContent: fileContent.split(',')[1],
        analysisType,
        userId: 'user-' + Math.random().toString(36).substr(2, 9),
      };

      console.log('📤 Uploading file:', file.name);
      const response = await this.client.post<JobResponse>('/upload', request);
      console.log('✅ Upload response:', response.data);

      return adaptJob(response.data);
    } catch (error: any) {
      console.error('❌ Upload failed:', error);
      throw new Error(`Upload failed: ${error.response?.data?.error || error.message}`);
    }
  }

  // ✅ NEW: NCBI Fetch method
  async fetchFromNCBI(accessionId: string, analysisType: 'fastqc' | 'blast'): Promise<Job> {
    try {
      console.log('🧬 Fetching from NCBI:', accessionId);
      const request: NCBIFetchRequest = {
        accessionId,
        analysisType,
        userId: 'user-' + Math.random().toString(36).substr(2, 9),
      };

      const response = await this.client.post<JobResponse>('/fetch-ncbi', request);
      console.log('✅ NCBI fetch response:', response.data);

      return adaptJob(response.data);
    } catch (error: any) {
      console.error('❌ NCBI fetch failed:', error);
      if (error.response?.status === 404) {
        throw new Error(`NCBI fetch endpoint not found. Make sure /fetch-ncbi is configured.`);
      }
      throw new Error(`NCBI fetch failed: ${error.response?.data?.error || error.message}`);
    }
  }

  async getJob(jobId: string): Promise<JobResponse> {
    try {
      console.log('🔍 Fetching job:', jobId);
      const response = await this.client.get<JobResponse>(`/jobs/${jobId}`);
      const data = response.data;
      console.log('✅ Raw job details from API:', data);

      return data;
    } catch (error: any) {
      console.error('❌ Get job failed:', error);
      if (error.response?.status === 404) {
        throw new Error(`Job ${jobId} not found`);
      }
      throw new Error(`Failed to fetch job: ${error.response?.data?.error || error.message}`);
    }
  }

  // ✅ ADDED: Get job and adapt to frontend format
  async getJobAdapted(jobId: string): Promise<Job> {
    const jobResponse = await this.getJob(jobId);
    return adaptJob(jobResponse);
  }

  async downloadFile(fileKey: string): Promise<DownloadResponse> {
    try {
      console.log('📥 Generating download URL for:', fileKey);
      const response = await this.client.get<DownloadResponse>('/download', {
        params: { fileKey }
      });
      console.log('✅ Download response:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Download failed:', error);
      if (error.response?.status === 404) {
        throw new Error('FILE_NOT_FOUND');
      }
      throw new Error(`Download failed: ${error.response?.data?.error || error.message}`);
    }
  }

  private fileToBase64(file: File): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.readAsDataURL(file);
      reader.onload = () => resolve(reader.result as string);
      reader.onerror = reject;
    });
  }
}

export const bioinformaticsAPI = new BioinformaticsAPI();