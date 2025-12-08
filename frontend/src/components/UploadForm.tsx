import React, { useState } from 'react';
import { bioinformaticsAPI } from '../services/api';
import { Job } from '../App';
import './UploadForm.css';

interface UploadFormProps {
  onUpload: (file: File, analysisType: 'fastqc' | 'blast') => void;
  onJobCreated: (job: Job) => void;   // ✅ REQUIRED
  disabled?: boolean;
}

const UploadForm: React.FC<UploadFormProps> = ({ onUpload, onJobCreated, disabled }) => {
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [analysisType, setAnalysisType] = useState<'fastqc' | 'blast'>('fastqc');

  // NCBI fields
  const [accessionId, setAccessionId] = useState('');
  const [fetchAnalysisType, setFetchAnalysisType] = useState<'fastqc' | 'blast'>('blast');

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    if (event.target.files && event.target.files[0]) {
      setSelectedFile(event.target.files[0]);
    }
  };

  const handleSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    if (selectedFile) {
      onUpload(selectedFile, analysisType);
    }
  };

  // 🔥 NCBI Fetch Handler
  const handleFetchNCBI = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!accessionId.trim()) {
      alert("Accession ID required");
      return;
    }

    try {
      const apiJob = await bioinformaticsAPI.fetchFromNCBI(accessionId, fetchAnalysisType);

      const frontendJob: Job = {
        id: apiJob.id,
        type: apiJob.type,
        status: apiJob.status,
        filename: apiJob.filename,
        createdAt: apiJob.createdAt ? new Date(apiJob.createdAt) : new Date(),
        batchJobId: apiJob.batchJobId
      };

      onJobCreated(frontendJob);
      setAccessionId('');
    } catch (error) {
      console.error("NCBI Fetch Error:", error);
      alert("Failed to fetch from NCBI");
    }
  };

  return (
    <div className="upload-form">
      <h2>Bioinformatics Analysis</h2>

      <div className="input-modes">
        {/* FILE UPLOAD */}
        <div className="mode-section">
          <h3>Upload File</h3>
          <form onSubmit={handleSubmit}>
            <div className="form-group">
              <label>Analysis Type:</label>
              <select
                value={analysisType}
                onChange={(e) => setAnalysisType(e.target.value as 'fastqc' | 'blast')}
              >
                <option value="fastqc">FastQC (FASTQ)</option>
                <option value="blast">BLAST (FASTA)</option>
              </select>
            </div>

            <div className="form-group">
              <label>Select File:</label>
              <input
                type="file"
                onChange={handleFileChange}
                accept={analysisType === 'fastqc' ? '.fastq,.fq' : '.fasta,.fa,.fas'}
              />
            </div>

            <button type="submit" disabled={!selectedFile || disabled}>
              {disabled ? "Processing..." : "Start Analysis"}
            </button>
          </form>
        </div>

        <div className="divider">OR</div>

        {/* NCBI FETCH */}
        <div className="mode-section">
          <h3>Fetch from NCBI</h3>

          <form onSubmit={handleFetchNCBI} className="ncbi-form">
            <input
              type="text"
              placeholder="Accession ID (e.g., SRR123456)"
              value={accessionId}
              onChange={(e) => setAccessionId(e.target.value)}
            />

            <select
              value={fetchAnalysisType}
              onChange={(e) => setFetchAnalysisType(e.target.value as 'fastqc' | 'blast')}
            >
              <option value="blast">BLAST Analysis</option>
              <option value="fastqc">FastQC Analysis</option>
            </select>

            <button type="submit" disabled={disabled}>
              {disabled ? "Processing..." : "Fetch and Analyze"}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
};

export default UploadForm;
