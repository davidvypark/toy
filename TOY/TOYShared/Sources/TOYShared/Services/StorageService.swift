import Foundation
import Supabase
import Storage

// MARK: - Upload Error

/// Errors that can occur during storage operations
public enum UploadError: LocalizedError, Sendable {
    case fileNotFound
    case uploadFailed(String)
    case signedURLFailed(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "The video file could not be found."
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .signedURLFailed(let message):
            return "Could not generate signed URL: \(message)"
        }
    }
}

// MARK: - Storage Service

/// Actor-based storage service for video upload to Supabase Storage.
/// Uses actor isolation for thread safety with async operations.
public actor StorageService {

    /// The storage bucket name for video clips
    private let bucketName = "clips"

    public init() {}

    // MARK: - Upload

    /// Uploads a video file to Supabase Storage.
    /// - Parameters:
    ///   - fileURL: The local URL of the video file to upload
    ///   - clipId: The unique identifier for this clip (used as filename)
    /// - Returns: The storage path of the uploaded file
    /// - Throws: `UploadError` if the file cannot be read or upload fails
    public func uploadVideo(fileURL: URL, clipId: UUID) async throws -> String {
        // Verify file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw UploadError.fileNotFound
        }

        // Read file data
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            throw UploadError.fileNotFound
        }

        let path = "\(clipId).mov"
        let bucket = supabase.storage.from(bucketName)

        do {
            try await bucket.upload(
                path: path,
                file: fileData,
                options: FileOptions(
                    cacheControl: "3600",
                    contentType: "video/quicktime",
                    upsert: false
                )
            )

            #if DEBUG
            let fileSizeKB = fileData.count / 1024
            print("📤 Uploaded \(path) (\(fileSizeKB) KB)")
            #endif

            return path
        } catch {
            throw UploadError.uploadFailed(error.localizedDescription)
        }
    }

    // MARK: - Signed URL

    /// Creates a time-limited signed URL for secure video access.
    /// - Parameters:
    ///   - path: The storage path of the file
    ///   - expiresIn: How long the URL should be valid, in seconds (default: 1 hour)
    /// - Returns: A signed URL for accessing the video
    /// - Throws: `UploadError.signedURLFailed` if URL generation fails
    public func createSignedURL(path: String, expiresIn: Int = 3600) async throws -> URL {
        let bucket = supabase.storage.from(bucketName)

        do {
            let signedURL = try await bucket.createSignedURL(path: path, expiresIn: expiresIn)

            #if DEBUG
            print("🔗 Created signed URL for \(path) (expires in \(expiresIn)s)")
            #endif

            return signedURL
        } catch {
            throw UploadError.signedURLFailed(error.localizedDescription)
        }
    }
}
