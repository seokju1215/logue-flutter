import 'package:amplitude_flutter/amplitude.dart';

class AmplitudeUtil {
  static final Amplitude _amplitude = Amplitude.getInstance(instanceName: "default");

  static void log(String eventName, {Map<String, dynamic>? props}) {
    _amplitude.logEvent(eventName, eventProperties: props ?? {});
  }

  static void setUserId(String userId) {
    _amplitude.setUserId(userId);
  }

  static void setUserProperties(Map<String, dynamic> props) {
    _amplitude.setUserProperties(props);
  }
}