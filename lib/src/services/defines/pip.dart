enum ZegoPiPStatus {
  /// App is currently shrank to PiP.
  enabled,

  /// App is currently not floating over others.
  disabled,

  /// App will shrink once the user will try to minimize the app.
  automatic,

  /// PiP mode is not available on this device.
  unavailable,
}
