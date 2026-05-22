import CoreLocation
import AVFoundation
import HealthKit

final class PermissionsService: NSObject {
    private let locationManager = CLLocationManager()
    private let healthStore = HKHealthStore()
    private var locationCompletion: ((Bool) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestLocation(completion: @escaping (Bool) -> Void) {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            DispatchQueue.main.async { completion(true) }
        case .denied, .restricted:
            DispatchQueue.main.async { completion(false) }
        case .notDetermined:
            locationCompletion = completion
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            DispatchQueue.main.async { completion(false) }
        }
    }

    func requestMicrophone(completion: @escaping (Bool) -> Void) {
        let deliver: (Bool) -> Void = { granted in
            DispatchQueue.main.async { completion(granted) }
        }
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: deliver)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(deliver)
        }
    }

    func requestCamera(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func requestHealthKit(completion: @escaping (Bool) -> Void) {
        let available = HKHealthStore.isHealthDataAvailable()
        print("[PermissionsService] HealthKit isHealthDataAvailable: \(available)")
        guard available,
              let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("[PermissionsService] HealthKit unavailable or heartRate type missing")
            DispatchQueue.main.async { completion(false) }
            return
        }
        healthStore.requestAuthorization(toShare: nil, read: [heartRate]) { success, error in
            print("[PermissionsService] HealthKit requestAuthorization success: \(success), error: \(String(describing: error))")
            DispatchQueue.main.async { completion(success && error == nil) }
        }
    }
}

extension PermissionsService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let granted: Bool
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            granted = true
        case .denied, .restricted:
            granted = false
        case .notDetermined:
            return
        @unknown default:
            granted = false
        }
        let completion = locationCompletion
        locationCompletion = nil
        DispatchQueue.main.async {
            completion?(granted)
        }
    }
}
