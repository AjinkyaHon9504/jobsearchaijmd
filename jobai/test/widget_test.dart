// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobai/main.dart';

void main() {
  testWidgets('Job Posting App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const JobPostingApp());

    // Verify that the bottom navigation bar is present
    expect(find.byType(NavigationBar), findsOneWidget);

    // Verify that both tabs are present
    expect(find.text('Chatbot'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);

    // Verify that the chatbot page is displayed by default
    expect(find.text('AI Job Assistant'), findsOneWidget);
    expect(find.text('Upload Your Resume'), findsOneWidget);

    // Tap the Dashboard tab
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    // Verify that the dashboard page is now displayed
    expect(find.text('Job Dashboard'), findsOneWidget);
    
    // Verify that job cards are displayed
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('Chatbot page displays upload prompt', (WidgetTester tester) async {
    await tester.pumpWidget(const JobPostingApp());

    // Verify upload prompt is visible
    expect(find.text('Upload Your Resume'), findsOneWidget);
    expect(find.text('Upload Resume (PDF)'), findsOneWidget);
    expect(find.byIcon(Icons.upload_file), findsOneWidget);
  });

  testWidgets('Dashboard displays job listings', (WidgetTester tester) async {
    await tester.pumpWidget(const JobPostingApp());

    // Navigate to Dashboard
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    // Verify dashboard elements
    expect(find.text('Job Dashboard'), findsOneWidget);
    expect(find.byIcon(Icons.filter_list), findsOneWidget);
    
    // Verify at least one job card is present
    expect(find.byType(Card), findsWidgets);
  });

  testWidgets('Navigation between tabs works', (WidgetTester tester) async {
    await tester.pumpWidget(const JobPostingApp());

    // Start on Chatbot page
    expect(find.text('AI Job Assistant'), findsOneWidget);

    // Navigate to Dashboard
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Job Dashboard'), findsOneWidget);

    // Navigate back to Chatbot
    await tester.tap(find.text('Chatbot'));
    await tester.pumpAndSettle();
    expect(find.text('AI Job Assistant'), findsOneWidget);
  });
}