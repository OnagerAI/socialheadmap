import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialheadmap/theme.dart';
import 'package:socialheadmap/widgets/question_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: ShmTheme.light,
      darkTheme: ShmTheme.dark,
      home: Scaffold(body: child),
    );

void main() {
  test('Light- und Dark-Theme enthalten die ShmColors-Extension', () {
    expect(ShmTheme.light.extension<ShmColors>(), isNotNull);
    expect(ShmTheme.dark.extension<ShmColors>(), isNotNull);
  });

  testWidgets('QuestionCard zeigt Titel und öffnet das Vote-Sheet',
      (tester) async {
    String? voted;
    await tester.pumpWidget(_wrap(QuestionCard(
      title: 'Testfrage?',
      description: 'Beschreibung',
      category: 'Politik',
      answerType: 'binary',
      onAnswer: (a) => voted = a,
    )));

    expect(find.text('Testfrage?'), findsOneWidget);
    expect(find.text('Jetzt abstimmen'), findsOneWidget);

    await tester.tap(find.text('Jetzt abstimmen'));
    await tester.pumpAndSettle();

    expect(find.text('Ja'), findsOneWidget);
    expect(find.text('Nein'), findsOneWidget);

    await tester.tap(find.text('Ja'));
    await tester.pumpAndSettle();
    expect(voted, 'ja');
  });

  testWidgets('Abgestimmte QuestionCard zeigt Antwort und Karten-Button',
      (tester) async {
    await tester.pumpWidget(_wrap(QuestionCard(
      title: 'Testfrage?',
      description: null,
      category: 'Umwelt',
      answerType: 'binary',
      isVoted: true,
      myAnswer: 'ja',
      onViewMap: () {},
    )));

    expect(find.text('Ja'), findsOneWidget);
    expect(find.text('Ergebnisse auf der Karte'), findsOneWidget);
    expect(find.text('Jetzt abstimmen'), findsNothing);
  });
}
