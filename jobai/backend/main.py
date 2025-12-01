"""
FastAPI Server for Resume Extraction
Run with: uvicorn main:app --reload
"""
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, List, Optional
import logging
import json
from datetime import datetime

# Import your resume extraction functions
from resumeextraction import (
    load_nlp_model,
    extract_resume_data,
    generate_search_keywords,
    validate_pdf
)

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Job Finder Resume Extraction API",
    description="Extract resume data and generate job search keywords",
    version="1.0.0"
)

# CORS middleware - allow Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load NLP model on startup
@app.on_event("startup")
async def startup_event():
    """Load spaCy model when server starts"""
    logger.info("Loading NLP model...")
    load_nlp_model()
    logger.info("✅ Server ready!")

# Response Models
class ContactInfo(BaseModel):
    name: Optional[str]
    email: Optional[str]
    phone: Optional[str]
    location: Optional[str]
    linkedin: Optional[str]
    github: Optional[str]

class Skills(BaseModel):
    programming_languages: List[str]
    web_technologies: List[str]
    mobile_development: List[str]
    databases: List[str]
    cloud_devops: List[str]
    data_science_ai: List[str]
    other_tools: List[str]
    all_skills: List[str]

class Experience(BaseModel):
    total_years: float
    positions: List[str]

class Education(BaseModel):
    degree: str
    year: Optional[str]
    cgpa: Optional[str]

class JobPreferences(BaseModel):
    job_types: List[str]
    preferred_locations: List[str]
    salary_expectation: Optional[str]
    remote_preference: bool

class SearchKeywords(BaseModel):
    primary_skills: List[str]
    job_titles: List[str]
    technologies: List[str]
    experience_level: str
    locations: List[str]

class ResumeDataResponse(BaseModel):
    contact_info: ContactInfo
    skills: Skills
    experience: Experience
    education: List[Education]
    projects: List[str]
    job_preferences: JobPreferences
    search_keywords: SearchKeywords
    raw_text_preview: str

# Endpoints
@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "active",
        "service": "Resume Extraction API",
        "version": "1.0.0",
        "endpoints": {
            "POST /api/extract-resume": "Extract resume data from PDF",
            "GET /health": "Health check"
        }
    }

@app.get("/health")
async def health():
    """Simple health check"""
    return {"status": "ok", "timestamp": datetime.now().isoformat()}

@app.post("/api/extract-resume", response_model=ResumeDataResponse)
async def extract_resume(resume: UploadFile = File(...)):
    """
    Extract resume data from uploaded PDF
    
    Args:
        resume: PDF file upload
        
    Returns:
        Complete resume data with search keywords
    """
    try:
        # Validate file type
        if not resume.filename.lower().endswith('.pdf'):
            raise HTTPException(
                status_code=400,
                detail="Only PDF files are allowed"
            )
        
        # Read file content
        content = await resume.read()
        
        # Validate PDF
        max_size = 20 * 1024 * 1024  # 20MB
        is_valid, msg = validate_pdf(content, resume.filename, max_size)
        if not is_valid:
            raise HTTPException(status_code=400, detail=msg)
        
        logger.info(f"Processing resume: {resume.filename}")
        
        # Extract resume data
        resume_data = extract_resume_data(content)
        
        # Generate search keywords
        search_keywords = generate_search_keywords(resume_data)
        
        # Combine data
        response_data = {
            "contact_info": resume_data['contact_info'],
            "skills": resume_data['skills'],
            "experience": resume_data['experience'],
            "education": resume_data['education'],
            "projects": resume_data['projects'],
            "job_preferences": resume_data['job_preferences'],
            "search_keywords": search_keywords,
            "raw_text_preview": resume_data['raw_text']
        }
        
        logger.info(f"✅ Resume processed successfully: {resume.filename}")
        
        # Save to JSON file (optional - for record keeping)
        save_to_json(resume.filename, response_data)
        
        return response_data
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error processing resume: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to process resume: {str(e)}"
        )

def save_to_json(filename: str, data: dict):
    """Save extracted data to JSON file"""
    try:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        json_filename = f"resume_data_{timestamp}.json"
        
        with open(json_filename, 'w', encoding='utf-8') as f:
            json.dump({
                "filename": filename,
                "processed_at": datetime.now().isoformat(),
                "data": data
            }, f, indent=2, ensure_ascii=False)
        
        logger.info(f"Data saved to {json_filename}")
    except Exception as e:
        logger.error(f"Failed to save JSON: {str(e)}")

# Run with: uvicorn main:app --reload --host 0.0.0.0 --port 8000
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)