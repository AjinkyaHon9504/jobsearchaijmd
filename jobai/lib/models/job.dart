import 'package:flutter/material.dart';

class Job {
  final String title;
  final String company;
  final String location;
  final String type;
  final String salary;
  final String description;
  final String postedDate;
  final Color logoColor;

  Job({
    required this.title,
    required this.company,
    required this.location,
    required this.type,
    required this.salary,
    required this.description,
    required this.postedDate,
    required this.logoColor,
  });
}