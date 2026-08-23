import 'package:flutter_test/flutter_test.dart';
import 'package:smartspot/models/reminder_condition.dart';

void main() {
  group('ReminderCondition Model Unit Tests', () {
    test('encodes and decodes timeAfter condition', () {
      final cond = ReminderCondition.timeAfter(9, 30); // 9:30 AM = 570 mins
      expect(cond.type, ConditionType.timeAfter);
      expect(cond.minutesSinceMidnight, 570);
      expect(cond.label, 'After 9:30 AM');

      final encoded = cond.encode();
      expect(encoded, 'timeAfter:570');

      final decoded = ReminderCondition.decode(encoded);
      expect(decoded?.type, ConditionType.timeAfter);
      expect(decoded?.minutesSinceMidnight, 570);
    });

    test('encodes and decodes weather conditions', () {
      final rain = ReminderCondition.rain();
      final clear = ReminderCondition.clear();

      expect(rain.label, 'If raining');
      expect(clear.label, 'If clear weather');

      expect(ReminderCondition.decode(rain.encode())?.type, ConditionType.weatherIsRain);
      expect(ReminderCondition.decode(clear.encode())?.type, ConditionType.weatherIsClear);
    });

    test('encodes and decodes condition lists', () {
      final list = [
        ReminderCondition.timeAfter(8, 0),
        ReminderCondition.onDay(1),
        ReminderCondition.rain(),
      ];

      final encodedStr = ReminderCondition.encodeList(list);
      expect(encodedStr, 'timeAfter:480;dayOfWeek:1;weatherIsRain');

      final decodedList = ReminderCondition.decodeList(encodedStr);
      expect(decodedList.length, 3);
      expect(decodedList[0].type, ConditionType.timeAfter);
      expect(decodedList[1].type, ConditionType.dayOfWeek);
      expect(decodedList[2].type, ConditionType.weatherIsRain);
    });
  });
}
