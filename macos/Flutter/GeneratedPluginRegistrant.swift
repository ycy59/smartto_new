//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import face_detection_tflite
import file_picker
import shared_preferences_foundation
import sqflite_darwin

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  FaceDetectionTflitePlugin.register(with: registry.registrar(forPlugin: "FaceDetectionTflitePlugin"))
  FilePickerPlugin.register(with: registry.registrar(forPlugin: "FilePickerPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  SqflitePlugin.register(with: registry.registrar(forPlugin: "SqflitePlugin"))
}
