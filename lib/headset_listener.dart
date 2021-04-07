import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

enum HeadsetState { CONNECTED, DISCONNECTED }
// ignore: unused_element
const _DEFAULT_IOS_AUDIO_SESSION_CONFIGURATIONS = true;

class HeadsetEvent {
  final HeadsetState state;
  final bool hasMicrophone;
  final String deviceName;

  HeadsetEvent({this.state, this.hasMicrophone, this.deviceName});
}

class HeadsetListener {
  static const MethodChannel _methodChannel =
      const MethodChannel('me.towerz.headsetlistener/method');

  static const EventChannel _eventChannel =
      const EventChannel('me.towerz.headsetlistener/event');

  final _headsetEventSubject = BehaviorSubject<HeadsetEvent>();

  StreamSubscription<dynamic> _eventSubscription;

  ValueStream<HeadsetEvent> get events => _headsetEventSubject.stream;
  bool _enableIOSDefaultAudioSessionConfiguration =
      _DEFAULT_IOS_AUDIO_SESSION_CONFIGURATIONS;
  set enableIOSDefaultAudioSessionConfiguration(bool newValue) {
    if (!Platform.isIOS) {
      return;
    }
    _enableIOSDefaultAudioSessionConfiguration = newValue;
    _methodChannel.invokeMethod('enableIOSDefaultAudioSessionConfiguration',
        {"isEnabled": _enableIOSDefaultAudioSessionConfiguration});
  }

  Future<HeadsetState> get headsetState async {
    final isHeadsetConnected =
        await _methodChannel.invokeMethod("isHeadphoneConnected");
    return isHeadsetConnected
        ? HeadsetState.CONNECTED
        : HeadsetState.DISCONNECTED;
  }

  Future<String> get deviceName async =>
      await _methodChannel.invokeMethod("deviceName");

  HeadsetListener() {
    _addNativeListener();
  }

  void dispose() {
    _headsetEventSubject.close();
    _removeNativeListener();
  }

  void _handleEvent(dynamic event) {
    final map = event as Map;
    switch (map['type']) {
      case 'DeviceChanged':
        final state = event['connected'] ?? false
            ? HeadsetState.CONNECTED
            : HeadsetState.DISCONNECTED;
        _headsetEventSubject.sink.add(
          HeadsetEvent(
              state: state,
              hasMicrophone: event['mic'],
              deviceName: event['deviceName']),
        );
        break;
      default:
        break;
    }
  }

  void _addNativeListener() async {
    _eventSubscription =
        _eventChannel.receiveBroadcastStream().listen(_handleEvent);
  }

  void _removeNativeListener() {
    _eventSubscription?.cancel();
  }
}
