# Load the model first


from resumeextraction import load_nlp_model
from resumeextraction import extract_resume_data, generate_search_keywords


load_nlp_model()

# Read PDF file
with open('resume.pdf', 'rb') as f:
    pdf_content = f.read()

# Extract all data
resume_data = extract_resume_data(pdf_content)

# Generate search keywords for job matching
search_keywords = generate_search_keywords(resume_data)

# Access extracted data
print("Name:", resume_data['contact_info']['name'])
print("Skills:", resume_data['skills']['all_skills'])
print("Experience:", resume_data['experience']['total_years'], "years")
print("Suggested Job Titles:", search_keywords['job_titles'])