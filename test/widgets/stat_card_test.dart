// test/widgets/stat_card_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Adjust the import path based on your project structure
import 'package:aquasense/screens/statistics/components/stat_card.dart';

void main() {
  testWidgets('StatCard displays title, value, and icon correctly',
          (WidgetTester tester) async {
        // Arrange: Define the test data
        const testTitle = 'Average Usage';
        const testValue = '25.5 m³';
        const testIcon = Icons.water_drop_outlined;
        const testColor = Colors.blueAccent;

        // Act: Build the StatCard widget within a test environment
        // We wrap it in MaterialApp and Scaffold to provide necessary context (like text direction).
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row( // StatCard uses Expanded, so it needs a Row/Column parent
                children: [
                  StatCard(
                    title: testTitle,
                    value: testValue,
                    icon: testIcon,
                    color: testColor,
                  ),
                ],
              ),
            ),
          ),
        );

        // Assert: Verify that the expected text and icon are found in the widget tree

        // Find Text widgets
        final titleFinder = find.text(testTitle);
        final valueFinder = find.text(testValue);

        // Find Icon widget
        final iconFinder = find.byIcon(testIcon);

        // Check if exactly one instance of each is found
        expect(titleFinder, findsOneWidget);
        expect(valueFinder, findsOneWidget);
        expect(iconFinder, findsOneWidget);

        // Optional: Check the color of the Icon
        final iconWidget = tester.widget<Icon>(iconFinder);
        expect(iconWidget.color, testColor);

        // Optional: Check the color in the Text Style for the value (more complex)
        final valueTextWidget = tester.widget<Text>(valueFinder);
        // Note: Comparing exact styles can be brittle. Check properties you care about.
        expect(valueTextWidget.style?.color, Colors.white); // Based on StatCard code
        expect(valueTextWidget.style?.fontWeight, FontWeight.bold);

      });

  // Add more testWidgets for other scenarios if needed (e.g., different colors)
}