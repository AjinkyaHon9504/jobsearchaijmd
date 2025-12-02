import 'package:flutter/material.dart';

class Job {
  final String id;
  final String title;
  final String company;
  final String location;
  final String type;
  final String salary;
  final String description;
  final String postedDate;
  final Color logoColor;
  final String? companyLogo;
  final String? jobUrl;
  final List<String>? highlights;

  Job({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.type,
    required this.salary,
    required this.description,
    required this.postedDate,
    required this.logoColor,
    this.companyLogo,
    this.jobUrl,
    this.highlights,
  });

  /// Create Job from JSearch API response
  factory Job.fromJSearchJson(Map<String, dynamic> json) {
    // Extract job details
    final jobId = json['job_id'] ?? '';
    final title = json['job_title'] ?? 'Job Title';
    final company = json['employer_name'] ?? 'Company';
    final location = json['job_city'] != null && json['job_state'] != null
        ? '${json['job_city']}, ${json['job_state']}'
        : json['job_country'] ?? 'Remote';
    
    // Job type
    final employmentType = json['job_employment_type'] ?? 'FULLTIME';
    final type = _formatEmploymentType(employmentType);
    
    // Salary info
    final minSalary = json['job_min_salary'];
    final maxSalary = json['job_max_salary'];
    final salary = _formatSalary(minSalary, maxSalary);
    
    // Description
    final description = json['job_description'] ?? 'No description available';
    
    // Posted date
    final postedDate = _formatPostedDate(json['job_posted_at_datetime_utc']);
    
    // Company logo
    final companyLogo = json['employer_logo'];
    
    // Job URL
    final jobUrl = json['job_apply_link'] ?? json['job_google_link'];
    
    // Highlights
    final highlights = json['job_highlights'] != null
        ? List<String>.from(json['job_highlights']['Qualifications'] ?? [])
        : <String>[];

    return Job(
      id: jobId,
      title: title,
      company: company,
      location: location,
      type: type,
      salary: salary,
      description: description.length > 200 
          ? '${description.substring(0, 200)}...' 
          : description,
      postedDate: postedDate,
      logoColor: _getColorFromString(company),
      companyLogo: companyLogo,
      jobUrl: jobUrl,
      highlights: highlights,
    );
  }

  static String _formatEmploymentType(String type) {
    switch (type.toUpperCase()) {
      case 'FULLTIME':
        return 'Full-time';
      case 'PARTTIME':
        return 'Part-time';
      case 'CONTRACTOR':
        return 'Contract';
      case 'INTERN':
        return 'Internship';
      default:
        return 'Full-time';
    }
  }

  static String _formatSalary(dynamic min, dynamic max) {
    if (min != null && max != null) {
      return '\$${_formatNumber(min)} - \$${_formatNumber(max)}/year';
    } else if (min != null) {
      return '\$${_formatNumber(min)}+/year';
    } else {
      return 'Salary not specified';
    }
  }

  static String _formatNumber(dynamic num) {
    if (num == null) return '0';
    final number = num is int ? num : (num as double).toInt();
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}k';
    }
    return number.toString();
  }

  static String _formatPostedDate(String? dateStr) {
    if (dateStr == null) return 'Recently';
    
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()} weeks ago';
      } else {
        return '${(difference.inDays / 30).floor()} months ago';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  static Color _getColorFromString(String str) {
    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.red,
      Colors.green,
    ];
    
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = str.codeUnitAt(i) + ((hash << 5) - hash);
    }
    
    return colors[hash.abs() % colors.length];
  }
}