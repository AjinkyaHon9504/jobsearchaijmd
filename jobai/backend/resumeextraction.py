"""
Resume data extraction for job search
Extracts: contact info, skills, experience, education, projects, preferences
"""
import re
import fitz
import spacy
from typing import Dict, List, Optional
from datetime import datetime
from dateutil.parser import parse as date_parse
import logging

logger = logging.getLogger(__name__)

# Global NLP model
nlp = None

def load_nlp_model():
    """Load spaCy NLP model"""
    global nlp
    try:
        nlp = spacy.load("en_core_web_sm")
        logger.info("✅ SpaCy model loaded")
    except OSError:
        logger.error("❌ SpaCy model not found. Install with: python -m spacy download en_core_web_sm")
        nlp = None

# ============================================================
# PDF EXTRACTION
# ============================================================

def extract_text_from_pdf(pdf_content: bytes) -> str:
    """Extract text from PDF bytes"""
    try:
        doc = fitz.open(stream=pdf_content, filetype="pdf")
        text = "".join([page.get_text() + "\n" for page in doc])
        doc.close()
        
        if not text.strip():
            raise Exception("PDF appears to be empty or contains only images")
        
        return text
    except Exception as e:
        logger.error(f"PDF extraction error: {e}")
        raise Exception(f"PDF extraction failed: {str(e)}")

def validate_pdf(content: bytes, filename: str, max_size_bytes: int = 20 * 1024 * 1024) -> tuple:
    """Validate PDF file"""
    if not filename.lower().endswith('.pdf'):
        return False, "File must be a PDF"
    
    if len(content) > max_size_bytes:
        max_mb = max_size_bytes / (1024 * 1024)
        return False, f"File size exceeds {max_mb}MB limit"
    
    return True, "Valid"

# ============================================================
# CONTACT INFORMATION EXTRACTION
# ============================================================

def extract_contact_info(text: str) -> Dict[str, Optional[str]]:
    """Extract name, email, phone, location, LinkedIn, GitHub"""
    
    contact_info = {
        'name': None,
        'email': None,
        'phone': None,
        'location': None,
        'linkedin': None,
        'github': None
    }
    
    # Extract email
    email_pattern = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
    emails = re.findall(email_pattern, text)
    if emails:
        contact_info['email'] = emails[0]
    
    # Extract phone (Indian and international formats)
    phone_patterns = [
        r'\+?\d{1,3}[-.\s]?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}',
        r'\+91[-.\s]?\d{10}',
        r'\d{10}'
    ]
    for pattern in phone_patterns:
        phones = re.findall(pattern, text)
        if phones:
            contact_info['phone'] = phones[0]
            break
    
    # Extract name (first few lines, typically name is at top)
    lines = [line.strip() for line in text.split('\n') if line.strip()]
    if lines:
        # Name is usually the first line or second line
        potential_name = lines[0]
        if len(potential_name.split()) <= 5 and not re.search(r'[@\d]', potential_name):
            contact_info['name'] = potential_name
    
    # Extract LinkedIn
    linkedin_pattern = r'(?:linkedin\.com/in/|linkedin\.com/pub/)([A-Za-z0-9_-]+)'
    linkedin_match = re.search(linkedin_pattern, text, re.IGNORECASE)
    if linkedin_match:
        contact_info['linkedin'] = f"https://linkedin.com/in/{linkedin_match.group(1)}"
    
    # Extract GitHub
    github_pattern = r'(?:github\.com/)([A-Za-z0-9_-]+)'
    github_match = re.search(github_pattern, text, re.IGNORECASE)
    if github_match:
        contact_info['github'] = f"https://github.com/{github_match.group(1)}"
    
    # Extract location (cities/states)
    location_pattern = r'\b(?:Mumbai|Delhi|Bangalore|Bengaluru|Hyderabad|Chennai|Kolkata|Pune|Ahmedabad|Jaipur|Chandigarh|Noida|Gurgaon|India)\b'
    location_match = re.search(location_pattern, text, re.IGNORECASE)
    if location_match:
        contact_info['location'] = location_match.group(0)
    
    return contact_info

# ============================================================
# SKILLS EXTRACTION
# ============================================================

def extract_skills(text: str) -> Dict[str, List[str]]:
    """Extract categorized skills"""
    
    skills_categories = {
        'programming_languages': {
            'Python', 'Java', 'JavaScript', 'TypeScript', 'C++', 'C#', 'C',
            'Ruby', 'PHP', 'Swift', 'Kotlin', 'Go', 'Rust', 'Scala', 'R',
            'Dart', 'Objective-C', 'Perl', 'Shell', 'Bash'
        },
        'web_technologies': {
            'React', 'Angular', 'Vue.js', 'Next.js', 'Node.js', 'Express',
            'Django', 'Flask', 'FastAPI', 'Spring Boot', 'ASP.NET',
            'HTML', 'CSS', 'SASS', 'Bootstrap', 'Tailwind', 'jQuery',
            'GraphQL', 'REST API', 'WebSocket', 'Redux', 'MobX'
        },
        'mobile_development': {
            'Flutter', 'React Native', 'Android', 'iOS', 'Kotlin', 'Swift',
            'Xamarin', 'Ionic', 'Cordova'
        },
        'databases': {
            'MongoDB', 'PostgreSQL', 'MySQL', 'Redis', 'Cassandra',
            'DynamoDB', 'Firebase', 'SQLite', 'Oracle', 'SQL Server',
            'Elasticsearch', 'Neo4j'
        },
        'cloud_devops': {
            'AWS', 'Azure', 'GCP', 'Google Cloud', 'Docker', 'Kubernetes',
            'Jenkins', 'CI/CD', 'Git', 'GitHub', 'GitLab', 'Terraform',
            'Ansible', 'Chef', 'Puppet', 'Linux', 'Nginx', 'Apache'
        },
        'data_science_ai': {
            'Machine Learning', 'Deep Learning', 'Data Science', 'TensorFlow',
            'PyTorch', 'Keras', 'Scikit-learn', 'Pandas', 'NumPy',
            'Matplotlib', 'Seaborn', 'NLP', 'Computer Vision', 'MLOps',
            'OpenCV', 'NLTK', 'SpaCy', 'Hugging Face'
        },
        'other_tools': {
            'Agile', 'Scrum', 'Jira', 'Postman', 'VS Code', 'IntelliJ',
            'Figma', 'Adobe XD', 'Photoshop', 'Microservices', 'Grafana',
            'Prometheus', 'Kafka', 'RabbitMQ', 'gRPC', 'OAuth', 'JWT'
        }
    }
    
    text_lower = text.lower()
    detected_skills = {
        'programming_languages': [],
        'web_technologies': [],
        'mobile_development': [],
        'databases': [],
        'cloud_devops': [],
        'data_science_ai': [],
        'other_tools': [],
        'all_skills': []
    }
    
    for category, skills_set in skills_categories.items():
        for skill in skills_set:
            pattern = r'\b' + re.escape(skill.lower()) + r'\b'
            if re.search(pattern, text_lower):
                detected_skills[category].append(skill)
                if skill not in detected_skills['all_skills']:
                    detected_skills['all_skills'].append(skill)
    
    return detected_skills

# ============================================================
# EXPERIENCE EXTRACTION
# ============================================================

def extract_experience(text: str) -> Dict:
    """Extract work experience details"""
    
    experience_data = {
        'total_years': 0.0,
        'positions': []
    }
    
    text_lower = text.lower()
    current_year = datetime.now().year
    
    # Direct years mention
    direct_patterns = [
        r'(\d+\.?\d*)\+?\s*(?:years?|yrs?)\s+(?:of\s+)?(?:work\s+)?experience',
        r'(?:work\s+)?experience[:\s]+(\d+\.?\d*)\+?\s*(?:years?|yrs?)',
    ]
    
    for pattern in direct_patterns:
        matches = re.findall(pattern, text_lower)
        if matches:
            years = [float(m) for m in matches if 0 < float(m) <= 50]
            if years:
                experience_data['total_years'] = float(max(years))
                break
    
    # Extract experience section
    exp_section_match = re.search(
        r'(?:professional\s+)?(?:work\s+)?experience[:\s]*\n(.*?)(?=\n\s*(?:education|projects|skills|certifications?|$))',
        text_lower,
        re.DOTALL | re.IGNORECASE
    )
    
    if exp_section_match:
        exp_text = exp_section_match.group(1)
        
        # Extract job positions (company names and titles)
        position_patterns = [
            r'([A-Z][a-z\s]+(?:Engineer|Developer|Manager|Lead|Architect|Analyst|Designer|Consultant))',
            r'(?:at|@)\s+([A-Z][A-Za-z\s&.,]+(?:Ltd|Inc|Corp|Pvt|LLC)?)'
        ]
        
        for pattern in position_patterns:
            positions = re.findall(pattern, text[:5000])  # First 5000 chars
            for pos in positions[:5]:  # Max 5 positions
                if pos not in experience_data['positions']:
                    experience_data['positions'].append(pos.strip())
    
    # Calculate from date ranges if total_years not found
    if experience_data['total_years'] == 0:
        date_ranges = re.findall(
            r'((?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{4})\s*[-–—to]\s*((?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{4}|present|current)',
            text_lower,
            re.IGNORECASE
        )
        
        total_months = 0
        for start_str, end_str in date_ranges:
            try:
                start_date = date_parse(start_str, fuzzy=True)
                end_date = datetime.now() if 'present' in end_str or 'current' in end_str else date_parse(end_str, fuzzy=True)
                
                if start_date.year >= 2000 and start_date <= datetime.now():
                    months_diff = (end_date.year - start_date.year) * 12 + (end_date.month - start_date.month)
                    if 0 < months_diff <= 240:
                        total_months += months_diff
            except:
                continue
        
        experience_data['total_years'] = round(total_months / 12, 1) if total_months > 0 else 0.0
    
    return experience_data

# ============================================================
# EDUCATION EXTRACTION
# ============================================================

def extract_education(text: str) -> List[Dict]:
    """Extract education details"""
    
    education_list = []
    
    # Find education section
    edu_section_match = re.search(
        r'education[:\s]*\n(.*?)(?=\n\s*(?:experience|projects|skills|certifications?|$))',
        text.lower(),
        re.DOTALL | re.IGNORECASE
    )
    
    if not edu_section_match:
        return education_list
    
    edu_text = edu_section_match.group(1)
    
    # Degree patterns
    degree_patterns = [
        r'(B\.?Tech|Bachelor|B\.?E\.?|B\.?S\.?|B\.?Sc)',
        r'(M\.?Tech|Master|M\.?E\.?|M\.?S\.?|M\.?Sc|MBA)',
        r'(Ph\.?D|Doctorate)'
    ]
    
    for pattern in degree_patterns:
        matches = re.finditer(pattern, edu_text, re.IGNORECASE)
        for match in matches:
            degree = match.group(0)
            
            # Try to find associated year
            context = edu_text[max(0, match.start()-50):match.end()+100]
            year_match = re.search(r'\b(19|20)\d{2}\b', context)
            year = year_match.group(0) if year_match else None
            
            # Try to find CGPA/percentage
            cgpa_match = re.search(r'(\d+\.?\d*)\s*(?:CGPA|GPA|%)', context, re.IGNORECASE)
            cgpa = cgpa_match.group(1) if cgpa_match else None
            
            education_list.append({
                'degree': degree,
                'year': year,
                'cgpa': cgpa
            })
    
    return education_list

# ============================================================
# PROJECTS EXTRACTION
# ============================================================

def extract_projects(text: str) -> List[str]:
    """Extract project names and descriptions"""
    
    projects = []
    
    # Find projects section
    proj_section_match = re.search(
        r'projects?[:\s]*\n(.*?)(?=\n\s*(?:experience|education|skills|certifications?|$))',
        text.lower(),
        re.DOTALL | re.IGNORECASE
    )
    
    if not proj_section_match:
        return projects
    
    proj_text = proj_section_match.group(1)
    
    # Split by bullet points or line breaks
    project_lines = re.split(r'\n\s*[•\-\*]\s*|\n{2,}', proj_text)
    
    for line in project_lines:
        line = line.strip()
        if len(line) > 20 and len(line) < 500:  # Reasonable project description length
            projects.append(line)
    
    return projects[:10]  # Max 10 projects

# ============================================================
# JOB PREFERENCES EXTRACTION
# ============================================================

def extract_job_preferences(text: str) -> Dict:
    """Extract job type preferences, location preferences, salary expectations"""
    
    preferences = {
        'job_types': [],
        'preferred_locations': [],
        'salary_expectation': None,
        'remote_preference': False
    }
    
    text_lower = text.lower()
    
    # Job type preferences
    if re.search(r'\bfull[- ]?time\b', text_lower):
        preferences['job_types'].append('Full-time')
    if re.search(r'\bpart[- ]?time\b', text_lower):
        preferences['job_types'].append('Part-time')
    if re.search(r'\bcontract\b', text_lower):
        preferences['job_types'].append('Contract')
    if re.search(r'\binternship\b', text_lower):
        preferences['job_types'].append('Internship')
    
    # Remote preference
    if re.search(r'\b(remote|work from home|wfh)\b', text_lower):
        preferences['remote_preference'] = True
    
    # Salary expectation (LPA for India, or general numbers)
    salary_patterns = [
        r'(\d+)\s*(?:-|to)\s*(\d+)\s*(?:lpa|lakhs?)',
        r'(?:salary|compensation|ctc)[:\s]*(?:₹|rs\.?|inr)?\s*(\d+)',
        r'(\d+)\s*(?:lpa|lakhs?)\s*(?:expected|desired|seeking)'
    ]
    
    for pattern in salary_patterns:
        match = re.search(pattern, text_lower)
        if match:
            preferences['salary_expectation'] = match.group(0)
            break
    
    # Preferred locations
    location_keywords = ['bangalore', 'bengaluru', 'mumbai', 'delhi', 'hyderabad', 
                        'chennai', 'pune', 'kolkata', 'remote', 'anywhere']
    
    for loc in location_keywords:
        if re.search(r'\b' + loc + r'\b', text_lower):
            preferences['preferred_locations'].append(loc.title())
    
    return preferences

# ============================================================
# MAIN EXTRACTION FUNCTION
# ============================================================

def extract_resume_data(pdf_content: bytes) -> Dict:
    """
    Main function to extract all resume data
    
    Args:
        pdf_content: PDF file content as bytes
        
    Returns:
        Dictionary with all extracted resume data
    """
    
    if not nlp:
        load_nlp_model()
    
    # Extract text from PDF
    text = extract_text_from_pdf(pdf_content)
    
    if len(text.strip()) < 100:
        raise Exception("Resume text too short")
    
    # Extract all components
    resume_data = {
        'contact_info': extract_contact_info(text),
        'skills': extract_skills(text),
        'experience': extract_experience(text),
        'education': extract_education(text),
        'projects': extract_projects(text),
        'job_preferences': extract_job_preferences(text),
        'raw_text': text[:1000]  # First 1000 chars for reference
    }
    
    return resume_data

# ============================================================
# KEYWORD GENERATION FOR JOB SEARCH
# ============================================================

"""
Enhanced keyword generation for job search
Generates MORE job titles based on skills
"""

def generate_search_keywords(resume_data: Dict) -> Dict[str, List[str]]:
    """
    Generate keywords for job search based on resume data
    
    Returns:
        Dictionary with categorized search keywords
    """
    
    search_keywords = {
        'primary_skills': resume_data['skills']['all_skills'][:10],
        'job_titles': [],
        'technologies': [],
        'experience_level': '',
        'locations': resume_data['job_preferences']['preferred_locations']
    }
    
    # Determine experience level
    years = resume_data['experience']['total_years']
    if years == 0:
        search_keywords['experience_level'] = 'Entry Level / Fresher'
    elif years <= 2:
        search_keywords['experience_level'] = 'Junior'
    elif years <= 5:
        search_keywords['experience_level'] = 'Mid-Level'
    else:
        search_keywords['experience_level'] = 'Senior'
    
    # Generate job titles based on skills
    skills = resume_data['skills']
    job_titles = set()  # Use set to avoid duplicates
    
    # Programming Languages
    if skills['programming_languages']:
        for lang in skills['programming_languages'][:3]:
            job_titles.add(f'{lang} Developer')
            if years >= 3:
                job_titles.add(f'Senior {lang} Developer')
        
        if 'Python' in skills['all_skills']:
            job_titles.update(['Python Developer', 'Backend Developer', 'Python Engineer'])
        if 'Java' in skills['all_skills']:
            job_titles.update(['Java Developer', 'Java Engineer', 'Backend Engineer'])
        if 'JavaScript' in skills['all_skills']:
            job_titles.update(['JavaScript Developer', 'Frontend Developer'])
    
    # Web Development
    if skills['web_technologies']:
        if 'React' in skills['all_skills']:
            job_titles.update([
                'React Developer', 'Frontend Developer', 'React.js Developer',
                'UI Developer', 'Frontend Engineer'
            ])
        if 'Angular' in skills['all_skills']:
            job_titles.update(['Angular Developer', 'Frontend Developer', 'UI Developer'])
        if 'Vue.js' in skills['all_skills']:
            job_titles.update(['Vue Developer', 'Frontend Developer', 'Vue.js Developer'])
        
        if 'Node.js' in skills['all_skills']:
            job_titles.update([
                'Node.js Developer', 'Backend Developer', 'Node Developer',
                'Backend Engineer', 'API Developer'
            ])
        if 'Express' in skills['all_skills']:
            job_titles.update(['Backend Developer', 'Node.js Developer'])
        
        # Full Stack
        if len(skills['web_technologies']) > 3:
            job_titles.update([
                'Full Stack Developer', 'Full Stack Engineer', 
                'Software Engineer', 'Web Developer'
            ])
        
        # Frameworks
        if 'Django' in skills['all_skills']:
            job_titles.update(['Django Developer', 'Python Developer', 'Backend Developer'])
        if 'Flask' in skills['all_skills']:
            job_titles.update(['Flask Developer', 'Python Developer'])
        if 'FastAPI' in skills['all_skills']:
            job_titles.update(['FastAPI Developer', 'Python Developer', 'API Developer'])
        if 'Spring Boot' in skills['all_skills']:
            job_titles.update(['Spring Boot Developer', 'Java Developer'])
        if 'Next.js' in skills['all_skills']:
            job_titles.update(['Next.js Developer', 'React Developer', 'Full Stack Developer'])
    
    # Mobile Development
    if skills['mobile_development']:
        job_titles.update(['Mobile Developer', 'Mobile Engineer', 'App Developer'])
        
        if 'Flutter' in skills['all_skills']:
            job_titles.update([
                'Flutter Developer', 'Flutter Engineer', 'Mobile App Developer',
                'Cross-Platform Developer', 'Dart Developer'
            ])
        if 'React Native' in skills['all_skills']:
            job_titles.update([
                'React Native Developer', 'Mobile Developer', 
                'Cross-Platform Developer', 'Mobile Engineer'
            ])
        if 'Android' in skills['all_skills']:
            job_titles.update(['Android Developer', 'Android Engineer', 'Mobile Developer'])
        if 'iOS' in skills['all_skills']:
            job_titles.update(['iOS Developer', 'iOS Engineer', 'Mobile Developer'])
        if 'Kotlin' in skills['all_skills']:
            job_titles.update(['Kotlin Developer', 'Android Developer'])
        if 'Swift' in skills['all_skills']:
            job_titles.update(['Swift Developer', 'iOS Developer'])
    
    # Data Science & AI
    if skills['data_science_ai']:
        if 'Machine Learning' in skills['all_skills']:
            job_titles.update([
                'Machine Learning Engineer', 'ML Engineer', 'AI Engineer',
                'Data Scientist', 'ML Developer'
            ])
        if 'Deep Learning' in skills['all_skills']:
            job_titles.update(['Deep Learning Engineer', 'AI Engineer', 'ML Engineer'])
        if 'Data Science' in skills['all_skills']:
            job_titles.update([
                'Data Scientist', 'Data Analyst', 'Data Engineer',
                'ML Engineer', 'Analytics Engineer'
            ])
        if 'TensorFlow' in skills['all_skills'] or 'PyTorch' in skills['all_skills']:
            job_titles.update(['ML Engineer', 'AI Developer', 'Deep Learning Engineer'])
        if 'NLP' in skills['all_skills']:
            job_titles.update(['NLP Engineer', 'ML Engineer', 'AI Developer'])
        if 'Computer Vision' in skills['all_skills']:
            job_titles.update(['Computer Vision Engineer', 'AI Engineer'])
        if 'MLOps' in skills['all_skills']:
            job_titles.update(['MLOps Engineer', 'ML Engineer', 'DevOps Engineer'])
    
    # Cloud & DevOps
    if skills['cloud_devops']:
        if 'AWS' in skills['all_skills']:
            job_titles.update([
                'AWS Developer', 'Cloud Engineer', 'DevOps Engineer',
                'Cloud Architect', 'Solutions Architect'
            ])
        if 'Azure' in skills['all_skills']:
            job_titles.update(['Azure Developer', 'Cloud Engineer', 'DevOps Engineer'])
        if 'GCP' in skills['all_skills'] or 'Google Cloud' in skills['all_skills']:
            job_titles.update(['GCP Developer', 'Cloud Engineer', 'DevOps Engineer'])
        
        if 'Docker' in skills['all_skills'] or 'Kubernetes' in skills['all_skills']:
            job_titles.update([
                'DevOps Engineer', 'Site Reliability Engineer', 'SRE',
                'Platform Engineer', 'Infrastructure Engineer'
            ])
        if 'CI/CD' in skills['all_skills']:
            job_titles.update(['DevOps Engineer', 'Build Engineer', 'Release Engineer'])
        if 'Terraform' in skills['all_skills']:
            job_titles.update(['DevOps Engineer', 'Infrastructure Engineer', 'Cloud Engineer'])
    
    # Database
    if skills['databases']:
        if 'MongoDB' in skills['all_skills']:
            job_titles.update(['Backend Developer', 'Database Developer'])
        if 'PostgreSQL' in skills['all_skills'] or 'MySQL' in skills['all_skills']:
            job_titles.update(['Backend Developer', 'Database Developer', 'Database Engineer'])
    
    # General Software Engineering (if no specific match)
    if not job_titles:
        job_titles.update([
            'Software Developer', 'Software Engineer', 'Application Developer',
            'Programmer', 'Software Development Engineer'
        ])
    
    # Add experience prefix for senior positions
    if years >= 5:
        senior_titles = set()
        for title in list(job_titles)[:10]:  # Add Senior to top 10
            if not title.startswith('Senior'):
                senior_titles.add(f'Senior {title}')
        job_titles.update(senior_titles)
    
    # Convert to list and limit
    search_keywords['job_titles'] = list(job_titles)[:20]  # Limit to 20 titles
    
    # Technologies for search
    search_keywords['technologies'] = skills['all_skills'][:15]
    
    return search_keywords