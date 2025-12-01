import 'package:flutter/material.dart';

class ResumeData {
  final ContactInfo contactInfo;
  final Skills skills;
  final Experience experience;
  final List<Education> education;
  final List<String> projects;
  final JobPreferences jobPreferences;
  final SearchKeywords searchKeywords;
  final String rawTextPreview;

  ResumeData({
    required this.contactInfo,
    required this.skills,
    required this.experience,
    required this.education,
    required this.projects,
    required this.jobPreferences,
    required this.searchKeywords,
    required this.rawTextPreview,
  });

  factory ResumeData.fromJson(Map<String, dynamic> json) {
    return ResumeData(
      contactInfo: ContactInfo.fromJson(json['contact_info']),
      skills: Skills.fromJson(json['skills']),
      experience: Experience.fromJson(json['experience']),
      education: (json['education'] as List)
          .map((e) => Education.fromJson(e))
          .toList(),
      projects: List<String>.from(json['projects']),
      jobPreferences: JobPreferences.fromJson(json['job_preferences']),
      searchKeywords: SearchKeywords.fromJson(json['search_keywords']),
      rawTextPreview: json['raw_text_preview'],
    );
  }
}

class ContactInfo {
  final String? name;
  final String? email;
  final String? phone;
  final String? location;
  final String? linkedin;
  final String? github;

  ContactInfo({
    this.name,
    this.email,
    this.phone,
    this.location,
    this.linkedin,
    this.github,
  });

  factory ContactInfo.fromJson(Map<String, dynamic> json) {
    return ContactInfo(
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      location: json['location'],
      linkedin: json['linkedin'],
      github: json['github'],
    );
  }
}

class Skills {
  final List<String> programmingLanguages;
  final List<String> webTechnologies;
  final List<String> mobileDevelopment;
  final List<String> databases;
  final List<String> cloudDevops;
  final List<String> dataScienceAi;
  final List<String> otherTools;
  final List<String> allSkills;

  Skills({
    required this.programmingLanguages,
    required this.webTechnologies,
    required this.mobileDevelopment,
    required this.databases,
    required this.cloudDevops,
    required this.dataScienceAi,
    required this.otherTools,
    required this.allSkills,
  });

  factory Skills.fromJson(Map<String, dynamic> json) {
    return Skills(
      programmingLanguages: List<String>.from(json['programming_languages']),
      webTechnologies: List<String>.from(json['web_technologies']),
      mobileDevelopment: List<String>.from(json['mobile_development']),
      databases: List<String>.from(json['databases']),
      cloudDevops: List<String>.from(json['cloud_devops']),
      dataScienceAi: List<String>.from(json['data_science_ai']),
      otherTools: List<String>.from(json['other_tools']),
      allSkills: List<String>.from(json['all_skills']),
    );
  }
}

class Experience {
  final double totalYears;
  final List<String> positions;

  Experience({required this.totalYears, required this.positions});

  factory Experience.fromJson(Map<String, dynamic> json) {
    return Experience(
      totalYears: (json['total_years'] as num).toDouble(),
      positions: List<String>.from(json['positions']),
    );
  }
}

class Education {
  final String degree;
  final String? year;
  final String? cgpa;

  Education({required this.degree, this.year, this.cgpa});

  factory Education.fromJson(Map<String, dynamic> json) {
    return Education(
      degree: json['degree'],
      year: json['year'],
      cgpa: json['cgpa'],
    );
  }
}

class JobPreferences {
  final List<String> jobTypes;
  final List<String> preferredLocations;
  final String? salaryExpectation;
  final bool remotePreference;

  JobPreferences({
    required this.jobTypes,
    required this.preferredLocations,
    this.salaryExpectation,
    required this.remotePreference,
  });

  factory JobPreferences.fromJson(Map<String, dynamic> json) {
    return JobPreferences(
      jobTypes: List<String>.from(json['job_types']),
      preferredLocations: List<String>.from(json['preferred_locations']),
      salaryExpectation: json['salary_expectation'],
      remotePreference: json['remote_preference'],
    );
  }
}

class SearchKeywords {
  final List<String> primarySkills;
  final List<String> jobTitles;
  final List<String> technologies;
  final String experienceLevel;
  final List<String> locations;

  SearchKeywords({
    required this.primarySkills,
    required this.jobTitles,
    required this.technologies,
    required this.experienceLevel,
    required this.locations,
  });

  factory SearchKeywords.fromJson(Map<String, dynamic> json) {
    return SearchKeywords(
      primarySkills: List<String>.from(json['primary_skills']),
      jobTitles: List<String>.from(json['job_titles']),
      technologies: List<String>.from(json['technologies']),
      experienceLevel: json['experience_level'],
      locations: List<String>.from(json['locations']),
    );
  }
}
