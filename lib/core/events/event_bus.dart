import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

final eventBusProvider = Provider<EventBus>((_) => EventBus());

class EventBus {
  final StreamController<AppEvent> _ctrl =
      StreamController<AppEvent>.broadcast();
  Stream<AppEvent> get stream => _ctrl.stream;
  void dispatch(AppEvent e) => _ctrl.add(e);
  Future<void> dispose() async => _ctrl.close();
}

@immutable
sealed class AppEvent {
  const AppEvent(this.kind);
  final String kind;
}

class ReminderDismissed extends AppEvent {
  const ReminderDismissed(this.disputeId) : super('reminder_dismissed');
  final String disputeId;
}
