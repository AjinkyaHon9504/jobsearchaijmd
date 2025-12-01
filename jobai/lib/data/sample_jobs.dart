import 'package:flutter/material.dart';
import '../models/job.dart';

final List<Job> sampleJobs = [
  Job(
    title: 'Senior Flutter Developer',
    company: 'TechCorp Inc',
    location: 'Remote',
    type: 'Full-time',
    salary: '\$80k - \$120k/year',
    description:
        'We are looking for an experienced Flutter developer to join our mobile team. You will be responsible for building cross-platform applications.',
    postedDate: '2 days ago',
    logoColor: Colors.blue,
  ),
  Job(
    title: 'Mobile App Developer',
    company: 'StartupHub',
    location: 'San Francisco, CA',
    type: 'Full-time',
    salary: '\$90k - \$130k/year',
    description:
        'Join our innovative startup to build the next generation of mobile experiences using Flutter and React Native.',
    postedDate: '1 week ago',
    logoColor: Colors.purple,
  ),
  Job(
    title: 'Frontend Developer',
    company: 'WebSolutions',
    location: 'New York, NY',
    type: 'Contract',
    salary: '\$70k - \$100k/year',
    description:
        'Looking for a skilled frontend developer with experience in modern web technologies and mobile development.',
    postedDate: '3 days ago',
    logoColor: Colors.orange,
  ),
  Job(
    title: 'Full Stack Developer',
    company: 'DataDrive',
    location: 'Austin, TX',
    type: 'Full-time',
    salary: '\$95k - \$140k/year',
    description:
        'Seeking a full stack developer to work on exciting projects involving mobile apps, web apps, and backend services.',
    postedDate: '5 days ago',
    logoColor: Colors.teal,
  ),
];