import simd

/// Camera-facing rules shared by RealityKit hit-testing and its unit tests.
///
/// A small positive threshold intentionally disables a face near the cube's
/// silhouette. At that angle its tiles are too narrow to touch reliably and a
/// finger can otherwise select the opposite face through a grid gap.
enum CubeInteractionGeometry {
    static let defaultMinimumFacingCosine: Float = 0.16

    static func isFaceTouchable(
        localNormal: SIMD3<Float>,
        cubeOrientation: simd_quatf,
        cameraPosition: SIMD3<Float>,
        cubeHalfExtent: Float,
        minimumFacingCosine: Float = defaultMinimumFacingCosine
    ) -> Bool {
        let normalLength = simd_length(localNormal)
        guard normalLength > 0.0001 else { return false }

        let localUnitNormal = localNormal / normalLength
        let worldNormal = simd_normalize(cubeOrientation.act(localUnitNormal))
        let faceCentre = cubeOrientation.act(localUnitNormal * cubeHalfExtent)
        let cameraVector = cameraPosition - faceCentre
        guard simd_length(cameraVector) > 0.0001 else { return false }

        return simd_dot(worldNormal, simd_normalize(cameraVector))
            >= minimumFacingCosine
    }
}
